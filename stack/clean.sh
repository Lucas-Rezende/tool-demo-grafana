#!/usr/bin/env bash
# Derruba o stack e apaga os volumes do projeto. NÃO toca em snapshot/:
# depois de um clean, 'make restore' devolve exatamente a mesma janela.
#
# Uso: ./stack/clean.sh [--sim]   (ou `make clean`)

source "$(dirname "${BASH_SOURCE[0]}")/_comum.sh"

exigir_docker
exigir_mltp

if [ "${1:-}" != "--sim" ]; then
  echo "Isso vai remover os containers e os volumes do projeto '$PROJETO'."
  echo "A pasta snapshot/ é preservada, então 'make restore' continua funcionando."
  read -r -p "Continuar? [s/N] " resposta
  [ "$resposta" = "s" ] || [ "$resposta" = "S" ] || { echo "Cancelado."; exit 0; }
fi

info "Derrubando containers"
dc down --remove-orphans || true

info "Removendo volumes"
for v in "${VOLUMES[@]}"; do
  if volume_existe "$v"; then
    docker volume rm -f "$(vol "$v")" >/dev/null
    ok "removido $(vol "$v")"
  fi
done

echo
ok "Limpo. snapshot/ intacto — rode 'make restore' para voltar à janela congelada."
