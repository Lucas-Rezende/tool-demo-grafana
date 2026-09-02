#!/usr/bin/env bash
# Congela a janela gravada: para os containers e exporta os volumes para
# snapshot/*.tgz. A partir daqui a demo não depende mais de tempo de espera.
#
# Uso: ./stack/freeze.sh   (ou `make freeze`)

source "$(dirname "${BASH_SOURCE[0]}")/_comum.sh"

exigir_docker
exigir_mltp

mkdir -p "$SNAPSHOT_DIR"

# `stop`, nunca `down`. `down` remove os containers e, para Loki, Tempo e
# Mimir, isso apagaria a camada gravável — que é exatamente onde os dados
# estariam se o nosso override não tivesse criado os volumes nomeados.
# `stop` também garante que os processos tenham fechado os arquivos antes do
# tar: exportar volume com o ingester escrevendo produz bloco corrompido.
info "Parando os containers (stop, não down)"
dc stop
ok "Containers parados"

FIM_MS="$(agora_ms)"

info "Exportando volumes para snapshot/"
FALTANDO=()
for v in "${VOLUMES[@]}"; do
  if ! volume_existe "$v"; then
    FALTANDO+=("$v")
    aviso "volume '$(vol "$v")' não existe; pulando"
    continue
  fi
  destino="$SNAPSHOT_DIR/$v.tgz"
  exportar_volume "$v" "$destino"
  tamanho="$(du -h "$destino" 2>/dev/null | cut -f1)"
  ok "$(vol "$v") -> snapshot/$v.tgz (${tamanho:-?})"
done

if [ "${#FALTANDO[@]}" -gt 0 ]; then
  erro "volumes ausentes: ${FALTANDO[*]}"
  erro "isso normalmente significa que o stack subiu sem o nosso override."
  erro "use sempre 'make record' / 'make restore', nunca 'docker compose up' direto."
  exit 1
fi

# Recupera o início da janela anotado por record.sh, se existir.
INICIO_MS=""
if [ -f "$SNAPSHOT_DIR/janela.env" ]; then
  # shellcheck disable=SC1091
  source "$SNAPSHOT_DIR/janela.env"
  INICIO_MS="${JANELA_INICIO_MS:-}"
fi

{
  printf 'JANELA_INICIO_MS=%s\n' "${INICIO_MS:-DESCONHECIDO}"
  printf 'JANELA_FIM_MS=%s\n' "$FIM_MS"
} > "$SNAPSHOT_DIR/janela.env"

{
  echo "Congelado em: $(ms_para_legivel "$FIM_MS")"
  echo "Fim da janela (epoch ms):    $FIM_MS"
  echo "Início da janela (epoch ms): ${INICIO_MS:-DESCONHECIDO — anote à mão}"
  echo
  echo "Restaure com: make restore"
  echo "Confira com:  make verify"
} > "$SNAPSHOT_DIR/congelado-em.txt"

cat <<FIM

$NEGRITO== Dataset congelado ==$RESET

  Início (epoch ms): ${INICIO_MS:-DESCONHECIDO}
  Fim    (epoch ms): $NEGRITO$FIM_MS$RESET
  Fim    (legível):  $(ms_para_legivel "$FIM_MS")

  Arquivos em: $SNAPSHOT_DIR

$NEGRITO O que fazer agora $RESET

  1. Copie os dois epochs para stack/JANELA.md.
  2. Rode 'make restore' e depois 'make verify' para provar que o ciclo fecha.
  3. Monte as URLs congeladas (&from=<início>&to=<fim>) e salve como
     favoritos, na ordem do roteiro. Ver docs/04-demo-reprodutivel.md.
  4. snapshot/ NÃO vai para o Git (é grande). Combine com o grupo como
     compartilhar: pendrive, Drive ou zip no Classroom.

FIM
