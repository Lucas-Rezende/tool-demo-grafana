#!/usr/bin/env bash
# Semáforo de cinco minutos: prova que a janela congelada ainda responde em
# todas as fontes de dados usadas na demo. Rode ANTES de subir ao projetor.
#
# Uso:
#   ./stack/verify.sh                       usa snapshot/janela.env
#   ./stack/verify.sh <inicio_ms> <fim_ms>  usa a janela informada

source "$(dirname "${BASH_SOURCE[0]}")/_comum.sh"

exigir_comando curl "Instale o curl (vem com o Git for Windows)."
exigir_docker
exigir_mltp

INICIO_MS="${1:-}"
FIM_MS="${2:-}"

if [ -z "$INICIO_MS" ] || [ -z "$FIM_MS" ]; then
  [ -f "$SNAPSHOT_DIR/janela.env" ] \
    || morrer "sem janela informada e sem snapshot/janela.env. Use: ./stack/verify.sh <inicio_ms> <fim_ms>"
  # shellcheck disable=SC1091
  source "$SNAPSHOT_DIR/janela.env"
  INICIO_MS="${JANELA_INICIO_MS:-}"
  FIM_MS="${JANELA_FIM_MS:-}"
fi

case "$INICIO_MS$FIM_MS" in
  *[!0-9]*|"") morrer "janela inválida: início='$INICIO_MS' fim='$FIM_MS'. Ambos precisam ser epoch em MILISSEGUNDOS." ;;
esac
[ "$FIM_MS" -gt "$INICIO_MS" ] || morrer "o fim da janela ($FIM_MS) não é maior que o início ($INICIO_MS)."

INICIO_S=$(( INICIO_MS / 1000 ))
FIM_S=$(( FIM_MS / 1000 ))
MEIO_S=$(( (INICIO_S + FIM_S) / 2 ))
INICIO_NS="${INICIO_MS}000000"
FIM_NS="${FIM_MS}000000"

echo
echo "${NEGRITO}Janela verificada${RESET}"
echo "  início: $INICIO_MS  ($(ms_para_legivel "$INICIO_MS"))"
echo "  fim:    $FIM_MS  ($(ms_para_legivel "$FIM_MS"))"
echo "  duração: $(( (FIM_S - INICIO_S) / 60 )) min"
echo

FALHAS=0

checar() {
  local nome="$1"; shift
  if "$@"; then
    printf '  %s[ OK ]%s %s\n' "$VERDE" "$RESET" "$nome"
  else
    printf '  %s[FALHOU]%s %s\n' "$VERMELHO" "$RESET" "$nome"
    FALHAS=$(( FALHAS + 1 ))
  fi
}

# --- containers -------------------------------------------------------------

servico_no_ar() {
  dc ps --services --filter status=running 2>/dev/null | grep -qx "$1"
}

k6_fora_do_ar() {
  ! servico_no_ar k6
}

# --- fontes de dados --------------------------------------------------------

grafana_saudavel() {
  curl -fsS --max-time 10 "http://localhost:$PORTA_GRAFANA/api/health" 2>/dev/null \
    | grep -q '"database": *"ok"'
}

# Métrica gerada pelo metrics-generator do Tempo, usada pelos painéis de erro
# e latência do MLT Dashboard. Se ela responde no meio da janela, os painéis
# principais da demo vão desenhar.
mimir_tem_metricas() {
  local r
  r="$(curl -fsS --max-time 15 -G \
        --data-urlencode 'query=count(traces_spanmetrics_calls_total)' \
        --data-urlencode "time=$MEIO_S" \
        "http://localhost:$PORTA_MIMIR/prometheus/api/v1/query" 2>/dev/null)" || return 1
  echo "$r" | grep -q '"status":"success"' && ! echo "$r" | grep -q '"result":\[\]'
}

# Métrica exposta pela própria aplicação (painel de percentil 95).
mimir_tem_metricas_da_app() {
  local r
  r="$(curl -fsS --max-time 15 -G \
        --data-urlencode 'query=count(mythical_request_times_bucket)' \
        --data-urlencode "time=$MEIO_S" \
        "http://localhost:$PORTA_MIMIR/prometheus/api/v1/query" 2>/dev/null)" || return 1
  echo "$r" | grep -q '"status":"success"' && ! echo "$r" | grep -q '"result":\[\]'
}

loki_tem_logs() {
  local r
  r="$(curl -fsS --max-time 20 -G \
        --data-urlencode 'query={job="alloy"}' \
        --data-urlencode "start=$INICIO_NS" \
        --data-urlencode "end=$FIM_NS" \
        --data-urlencode 'limit=1' \
        "http://localhost:$PORTA_LOKI/loki/api/v1/query_range" 2>/dev/null)" || return 1
  echo "$r" | grep -q '"status":"success"' && ! echo "$r" | grep -q '"result":\[\]'
}

# O bloco 2 da apresentação depende de encontrar log de erro dentro da janela.
loki_tem_erros() {
  local r
  r="$(curl -fsS --max-time 30 -G \
        --data-urlencode 'query={job="alloy"} | logfmt | status="Error"' \
        --data-urlencode "start=$INICIO_NS" \
        --data-urlencode "end=$FIM_NS" \
        --data-urlencode 'limit=1' \
        "http://localhost:$PORTA_LOKI/loki/api/v1/query_range" 2>/dev/null)" || return 1
  echo "$r" | grep -q '"status":"success"' && ! echo "$r" | grep -q '"result":\[\]'
}

# Esta é a checagem mais importante: é o Tempo que sofre com block_retention.
# Se ela falhar e as outras passarem, quase certamente o setup.sh não rodou e
# a retenção continua em 1h.
tempo_tem_traces() {
  curl -fsS --max-time 30 -G \
    --data-urlencode 'q={}' \
    --data-urlencode "start=$INICIO_S" \
    --data-urlencode "end=$FIM_S" \
    --data-urlencode 'limit=1' \
    "http://localhost:$PORTA_TEMPO/api/search" 2>/dev/null \
  | grep -q '"traceID"'
}

# Spans com erro são o clímax do bloco 2. Sem isso, não há cascata para mostrar.
tempo_tem_erros() {
  curl -fsS --max-time 30 -G \
    --data-urlencode 'q={status=error}' \
    --data-urlencode "start=$INICIO_S" \
    --data-urlencode "end=$FIM_S" \
    --data-urlencode 'limit=1' \
    "http://localhost:$PORTA_TEMPO/api/search" 2>/dev/null \
  | grep -q '"traceID"'
}

echo "${NEGRITO}Containers${RESET}"
for s in grafana mimir loki tempo alloy mythical-server mythical-requester; do
  checar "serviço '$s' no ar" servico_no_ar "$s"
done
checar "k6 FORA do ar (escopo do trabalho)" k6_fora_do_ar

echo
echo "${NEGRITO}Fontes de dados na janela congelada${RESET}"
checar "Grafana  — /api/health"                grafana_saudavel
checar "Mimir    — traces_spanmetrics_calls_total" mimir_tem_metricas
checar "Mimir    — mythical_request_times_bucket"  mimir_tem_metricas_da_app
checar "Loki     — linhas de log"                  loki_tem_logs
checar "Loki     — linhas com status=Error"        loki_tem_erros
checar "Tempo    — traces na janela"               tempo_tem_traces
checar "Tempo    — spans com erro"                 tempo_tem_erros

echo
if [ "$FALHAS" -eq 0 ]; then
  printf '%s Tudo verde. A demo está pronta para rodar.%s\n\n' "$VERDE$NEGRITO" "$RESET"
  exit 0
fi

printf '%s %s verificação(ões) falharam.%s\n\n' "$VERMELHO$NEGRITO" "$FALHAS" "$RESET"
cat <<'FIM'
  Como interpretar:

  - Só o Tempo falhou:      quase certamente o block_retention voltou a 1h.
                            Rode 'make setup' e grave a janela de novo.
  - Tudo falhou:            o stack não subiu ou a janela informada está errada.
                            Confira 'make restore' e os epochs em stack/JANELA.md.
  - Só 'spans com erro':    a janela pegou um período calmo demais.
                            Regrave com mais tempo ('make record --do-zero').
  - k6 no ar:               alguém subiu o stack sem --scale k6=0.
                            Use 'make restore'; nunca 'docker compose up' direto.

  Plano B em docs/07-plano-de-contingencia.md.
FIM
exit 1
