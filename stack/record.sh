#!/usr/bin/env bash
# Sobe o stack para GRAVAR a janela de dados que será usada na apresentação.
# Roda uma vez (mais os ensaios). Depois de ~45 min, rode ./stack/freeze.sh.
#
# Uso:
#   ./stack/record.sh            sobe o stack e começa/continua a gravação
#   ./stack/record.sh --do-zero  apaga os volumes antes, para gravar do zero

source "$(dirname "${BASH_SOURCE[0]}")/_comum.sh"

DO_ZERO=0
case "${1:-}" in
  --do-zero) DO_ZERO=1 ;;
  "")        ;;
  *)         morrer "argumento desconhecido '$1'. Use --do-zero ou nenhum argumento." ;;
esac

exigir_docker
exigir_mltp

if [ ! -f "$REPO_RAIZ/stack/.setup-info" ]; then
  aviso "não encontrei stack/.setup-info — parece que 'make setup' nunca rodou."
  aviso "sem ele, o block_retention do Tempo continua em 1h e os traces somem."
  morrer "rode 'make setup' antes de gravar."
fi

if [ "$DO_ZERO" = "1" ]; then
  info "Apagando containers e volumes para gravar do zero"
  dc down --remove-orphans >/dev/null 2>&1 || true
  for v in "${VOLUMES[@]}"; do
    docker volume rm -f "$(vol "$v")" >/dev/null 2>&1 || true
  done
  ok "Volumes removidos"
fi

# --scale k6=0: o k6 é ferramenta de teste de carga e está fora do escopo do
# trabalho. A carga da demo vem do mythical-requester, que já gera tráfego e
# erros sozinho, sem que a gente precise de gerador de carga nenhum.
info "Subindo o stack sem o k6"
subir_sem_k6
ok "Containers no ar"

info "Esperando o Grafana responder"
for _ in $(seq 1 60); do
  if curl -fsS "http://localhost:$PORTA_GRAFANA/api/health" >/dev/null 2>&1; then
    ok "Grafana respondendo em http://localhost:$PORTA_GRAFANA"
    break
  fi
  sleep 2
done
curl -fsS "http://localhost:$PORTA_GRAFANA/api/health" >/dev/null 2>&1 \
  || aviso "o Grafana ainda não respondeu. Ele baixa plugins no primeiro boot; espere mais um pouco."

# Confere que o k6 realmente não subiu. Barato e evita descobrir tarde.
if dc ps --services --filter status=running 2>/dev/null | grep -qx k6; then
  erro "o container k6 está rodando. Derrube com 'docker compose ... stop k6' e suba de novo."
  exit 1
fi
ok "k6 fora do ar, como esperado"

INICIO_MS="$(agora_ms)"
mkdir -p "$SNAPSHOT_DIR"
# O epoch do início da janela é o número que vai para as URLs congeladas
# (&from=...) e para verify.sh. Anote-o também em stack/JANELA.md.
printf 'JANELA_INICIO_MS=%s\n' "$INICIO_MS" > "$SNAPSHOT_DIR/janela.env"

cat <<FIM

$NEGRITO== Janela de gravação aberta ==$RESET

  Início (epoch ms):  $NEGRITO$INICIO_MS$RESET
  Início (legível):   $(ms_para_legivel "$INICIO_MS")
  Anotado em:         snapshot/janela.env

  Grafana:            http://localhost:$PORTA_GRAFANA
  Aplicação exemplo:  http://localhost:$PORTA_APP
  Mimir:              http://localhost:$PORTA_MIMIR
  Loki:               http://localhost:$PORTA_LOKI
  Tempo:              http://localhost:$PORTA_TEMPO

$NEGRITO O que fazer agora $RESET

  1. Copie o epoch acima para stack/JANELA.md.
  2. Deixe o stack rodando por ~45 minutos sem mexer. O mythical-requester
     gera tráfego e erros sozinho; não é preciso gerar carga.
  3. Enquanto espera, abra o Grafana e monte o que precisa ficar salvo:
       - a CÓPIA do dashboard "MLT Dashboard" que será usada na demo
         (Export/Import ou "Save as"; o original é provisionado e não aceita
         edição salva);
       - as duas regras de alerta descritas em docs/04-demo-reprodutivel.md.
     Tudo isso vive no volume 'grafana' e será congelado junto com os dados.
  4. Não abra o Pyroscope nem o dashboard "Official k6 Test Result":
     estão fora do escopo (docs/03-escopo-e-fronteiras.md).
  5. Passados os ~45 min, rode: $NEGRITO make freeze$RESET

FIM
