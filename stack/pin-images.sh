#!/usr/bin/env bash
# Imprime as imagens mythical-* fixadas por digest, prontas para colar em
# stack/docker-compose.override.yml.
#
# Por quê: o compose oficial usa tags mutáveis
# (ghcr.io/grafana/intro-to-mltp:mythical-beasts-server-latest). A Grafana
# republica essas tags. Se a imagem mudar entre o ensaio e a apresentação, o
# comportamento da aplicação — inclusive quais endpoints dão erro — pode mudar
# junto, e o dataset congelado deixa de casar com o que está rodando.
#
# Uso: ./stack/pin-images.sh   (ou `make pin`)

source "$(dirname "${BASH_SOURCE[0]}")/_comum.sh"

exigir_docker
exigir_mltp

SERVICOS=(mythical-requester mythical-server mythical-recorder mythical-frontend)

info "Lendo as imagens declaradas no compose"
declare -A TAG
for s in "${SERVICOS[@]}"; do
  t="$(dc config --images "$s" 2>/dev/null | head -1 || true)"
  [ -n "$t" ] || morrer "não consegui descobrir a imagem do serviço '$s'. O compose oficial mudou?"
  TAG["$s"]="$t"
done

info "Garantindo que as imagens estão baixadas (o digest vem do registro)"
for s in "${SERVICOS[@]}"; do
  docker image inspect "${TAG[$s]}" >/dev/null 2>&1 || docker pull --quiet "${TAG[$s]}" >/dev/null
done

FALTOU=0
echo
echo "# ---- cole em stack/docker-compose.override.yml, dentro de 'services:' ----"
for s in "${SERVICOS[@]}"; do
  digest="$(docker image inspect "${TAG[$s]}" --format '{{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' 2>/dev/null || true)"
  if [ -z "$digest" ]; then
    echo "  # $s: SEM DIGEST (imagem construída localmente?) — mantenha a tag ${TAG[$s]}"
    FALTOU=1
    continue
  fi
  printf '  %s:\n    image: %s\n' "$s" "$digest"
done
echo "# ---- fim ----"
echo

if [ "$FALTOU" = "1" ]; then
  aviso "alguma imagem não tem digest publicado; veja os comentários acima."
fi
ok "Depois de colar, rode 'make restore' e 'make verify' para confirmar que nada quebrou."
