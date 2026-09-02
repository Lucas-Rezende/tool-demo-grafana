#!/usr/bin/env bash
# Semáforo de cinco minutos: prova que a janela congelada ainda responde em
# todas as fontes de dados usadas na demo. Rode ANTES de subir ao projetor.
#
# As consultas em si moram em stack/_comum.sh, porque restore.sh usa as mesmas
# para saber quando o stack terminou de aquecer.
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

servico_no_ar() {
  dc ps --services --filter status=running 2>/dev/null | grep -qx "$1"
}

k6_fora_do_ar() {
  ! servico_no_ar k6
}

echo "${NEGRITO}Containers${RESET}"
for s in grafana mimir loki tempo alloy mythical-server mythical-requester; do
  checar "serviço '$s' no ar" servico_no_ar "$s"
done
checar "k6 FORA do ar (escopo do trabalho)" k6_fora_do_ar

echo
echo "${NEGRITO}Fontes de dados na janela congelada${RESET}"

# Métrica gerada pelo metrics-generator do Tempo, usada pelos painéis de erro e
# de latência do MLT Dashboard. Se ela responde no meio da janela, os painéis
# principais da demo vão desenhar.
checar "Grafana  — /api/health" \
  grafana_saudavel
checar "Mimir    — traces_spanmetrics_calls_total" \
  mimir_responde "$MEIO_S" 'count(traces_spanmetrics_calls_total)'
# Métrica exposta pela própria aplicação (painel de percentil 95).
checar "Mimir    — mythical_request_times_bucket" \
  mimir_responde "$MEIO_S" 'count(mythical_request_times_bucket)'
checar "Loki     — linhas de log" \
  loki_responde "$INICIO_NS" "$FIM_NS" '{job="alloy"}'
# O bloco 2 da apresentação depende de encontrar log de erro dentro da janela.
checar "Loki     — linhas com status=Error" \
  loki_responde "$INICIO_NS" "$FIM_NS" '{job="alloy"} | logfmt | status="Error"'
# Esta é a checagem mais importante: é o Tempo que sofre com block_retention e
# com query_backend_after.
checar "Tempo    — traces na janela" \
  tempo_responde "$INICIO_S" "$FIM_S" '{}'
# Spans com erro são o clímax do bloco 2. Sem isso, não há cascata para mostrar.
checar "Tempo    — spans com erro" \
  tempo_responde "$INICIO_S" "$FIM_S" '{status=error}'

echo
if [ "$FALHAS" -eq 0 ]; then
  printf '%s Tudo verde. A demo está pronta para rodar.%s\n\n' "$VERDE$NEGRITO" "$RESET"
  exit 0
fi

printf '%s %s verificação(ões) falharam.%s\n\n' "$VERMELHO$NEGRITO" "$FALHAS" "$RESET"
cat <<'FIM'
  Como interpretar:

  - Acabou de rodar o restore:  espere um minuto e rode de novo. Loki e Tempo
                                levam alguns segundos para carregar índice e
                                lista de blocos depois de subir.

  - Só o Tempo falhou:          duas causas possíveis, nesta ordem.
                                (a) A janela tem menos de 15 min de idade e o
                                    query_backend_after não foi reduzido.
                                    Rode 'make setup' e depois 'make restore'.
                                (b) O block_retention voltou a 1h, normalmente
                                    por um 'git pull' em intro-to-mltp/.
                                    Rode 'make setup' e regrave a janela.

  - Tudo falhou:                o stack não subiu ou a janela está errada.
                                Confira 'make restore' e stack/JANELA.md.

  - Só 'spans com erro':        a janela pegou um período calmo demais.
                                Regrave com mais tempo ('make record --do-zero').

  - Algum mythical-* fora:      o Compose devolveu o controle com o container
                                em 'Created'. Rode 'make restore' de novo.

  - k6 no ar:                   alguém subiu o stack sem --scale k6=0.
                                Use 'make restore'; nunca 'docker compose up'.

  Plano B em docs/07-plano-de-contingencia.md.
FIM
exit 1
