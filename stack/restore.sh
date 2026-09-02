#!/usr/bin/env bash
# Restaura o dataset congelado e sobe o stack. É o único comando que precisa
# rodar no dia da apresentação. Idempotente: rodar dez vezes dá o mesmo
# resultado, porque os volumes são recriados do zero a cada execução.
#
# Uso: ./stack/restore.sh   (ou `make restore`)

source "$(dirname "${BASH_SOURCE[0]}")/_comum.sh"

exigir_docker
exigir_mltp

[ -d "$SNAPSHOT_DIR" ] || morrer "não encontrei '$SNAPSHOT_DIR'. Copie a pasta snapshot/ do pendrive antes."

info "Conferindo os tarballs"
for v in "${VOLUMES[@]}"; do
  [ -f "$SNAPSHOT_DIR/$v.tgz" ] || morrer "faltando snapshot/$v.tgz. O congelamento está incompleto."
done
ok "${#VOLUMES[@]} tarballs presentes"

# `down` derruba containers e rede. Os volumes nomeados sobrevivem a `down`,
# por isso eles são removidos explicitamente logo abaixo: restaurar por cima
# de dados antigos misturaria duas janelas.
info "Derrubando o stack anterior"
dc down --remove-orphans >/dev/null 2>&1 || true
ok "Containers removidos"

info "Recriando volumes"
for v in "${VOLUMES[@]}"; do
  docker volume rm -f "$(vol "$v")" >/dev/null 2>&1 || true
  docker volume create "$(vol "$v")" >/dev/null
done
ok "${#VOLUMES[@]} volumes vazios"

info "Restaurando dados"
for v in "${VOLUMES[@]}"; do
  importar_volume "$v" "$SNAPSHOT_DIR/$v.tgz"
  ok "snapshot/$v.tgz -> $(vol "$v")"
done

info "Subindo o stack sem o k6"
subir_sem_k6
ok "Containers no ar"

info "Esperando o Grafana ficar saudável"
SAUDAVEL=0
for _ in $(seq 1 90); do
  if curl -fsS "http://localhost:$PORTA_GRAFANA/api/health" 2>/dev/null | grep -q '"database": *"ok"'; then
    SAUDAVEL=1
    break
  fi
  sleep 2
done

if [ "$SAUDAVEL" != "1" ]; then
  erro "o Grafana não ficou saudável em 3 minutos."
  erro "veja os logs com: docker compose -f '$MLTP_DIR/docker-compose.yml' -f '$REPO_RAIZ/stack/docker-compose.override.yml' logs grafana"
  exit 1
fi
ok "Grafana saudável em http://localhost:$PORTA_GRAFANA"

if dc ps --services --filter status=running 2>/dev/null | grep -qx k6; then
  erro "o container k6 subiu. Isso não deveria acontecer com --scale k6=0."
  exit 1
fi
ok "k6 fora do ar, como esperado"

JANELA=""
if [ -f "$SNAPSHOT_DIR/janela.env" ]; then
  # shellcheck disable=SC1091
  source "$SNAPSHOT_DIR/janela.env"
  JANELA="${JANELA_INICIO_MS:-?} .. ${JANELA_FIM_MS:-?}"
fi

cat <<FIM

$NEGRITO== Stack restaurado ==$RESET

  Grafana:           http://localhost:$PORTA_GRAFANA
  Aplicação exemplo: http://localhost:$PORTA_APP
  Janela congelada:  ${JANELA:-veja stack/JANELA.md}

  Próximo passo: $NEGRITO make verify$RESET  (leva menos de um minuto)

  Lembre: o stack continua GERANDO dados novos a partir de agora. Os
  favoritos da demo usam intervalo absoluto, então isso não atrapalha —
  mas não troque o seletor de tempo para "Last 5 minutes" no meio da
  apresentação.

FIM
