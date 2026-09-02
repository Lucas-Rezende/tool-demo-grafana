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

# Cuidado: `docker compose config --images <servico>` também lista as imagens
# das dependências. Para mythical-server, por exemplo, a primeira linha é o
# postgres. Por isso filtramos pela imagem do próprio serviço em vez de pegar
# a primeira linha da saída.
TODAS="$(dc config --images 2>/dev/null)"
[ -n "$TODAS" ] || morrer "não consegui listar as imagens do projeto. O Compose está funcionando?"

info "Conferindo as imagens declaradas no compose"

PENDENTES=()
JA_FIXADOS=()
for s in "${SERVICOS[@]}"; do
  # mythical-server  ->  mythical-beasts-server-latest
  sufixo="${s#mythical-}"
  tag="$(printf '%s\n' "$TODAS" | grep -E "intro-to-mltp:mythical-beasts-${sufixo}-latest$" | head -1 || true)"
  if [ -n "$tag" ]; then
    PENDENTES+=("$s=$tag")
  elif printf '%s\n' "$TODAS" | grep -q "intro-to-mltp@sha256:"; then
    JA_FIXADOS+=("$s")
  else
    aviso "não achei a imagem do serviço '$s' na saída do compose."
    aviso "o repositório oficial pode ter renomeado a tag; confira à mão."
  fi
done

if [ "${#PENDENTES[@]}" -eq 0 ]; then
  ok "nenhuma tag mutável restante — as imagens já estão fixadas por digest."
  # O `|| true` importa: sem ele, o `set -e` derrubaria o script com status 1
  # justamente no caminho de sucesso.
  { [ "${#JA_FIXADOS[@]}" -gt 0 ] && info "serviços já fixados: ${JA_FIXADOS[*]}"; } || true
  exit 0
fi

info "Garantindo que as imagens estão baixadas (o digest vem do registro)"
for item in "${PENDENTES[@]}"; do
  tag="${item#*=}"
  docker image inspect "$tag" >/dev/null 2>&1 || docker pull --quiet "$tag" >/dev/null
done

FALTOU=0
echo
echo "# ---- cole em stack/docker-compose.override.yml, dentro de 'services:' ----"
for item in "${PENDENTES[@]}"; do
  s="${item%%=*}"
  tag="${item#*=}"
  digest="$(docker image inspect "$tag" --format '{{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' 2>/dev/null || true)"
  if [ -z "$digest" ]; then
    echo "  # $s: SEM DIGEST publicado — mantenha a tag $tag"
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
