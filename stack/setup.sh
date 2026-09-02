#!/usr/bin/env bash
# Prepara o ambiente para gravar a janela de dados.
# Roda uma vez por máquina. É idempotente: rodar de novo não estraga nada.
#
# Uso: ./stack/setup.sh   (ou `make setup`)

source "$(dirname "${BASH_SOURCE[0]}")/_comum.sh"

RETENCAO_ALVO="336h"   # 14 dias. Sobra folga entre a gravação e a apresentação.

info "Verificando pré-requisitos"
exigir_comando git "Instale o Git antes de continuar."
exigir_docker
ok "Docker e Git disponíveis"

# --- 1. clone do repositório oficial ---------------------------------------

if [ ! -d "$MLTP_DIR/.git" ]; then
  info "Clonando o intro-to-mltp em '$MLTP_DIR'"
  git clone "$MLTP_URL" "$MLTP_DIR"
else
  info "Clone já existe em '$MLTP_DIR'"
fi

# O repositório oficial recebe commits com frequência e já quebrou demos ao
# trocar o esquema dos dashboards. Fixar o commit é o que faz o ensaio e a
# apresentação verem exatamente o mesmo stack.
info "Fixando o commit $MLTP_COMMIT"
git -C "$MLTP_DIR" fetch --quiet origin "$MLTP_COMMIT" 2>/dev/null || git -C "$MLTP_DIR" fetch --quiet origin
if ! git -C "$MLTP_DIR" cat-file -e "${MLTP_COMMIT}^{commit}" 2>/dev/null; then
  morrer "o commit $MLTP_COMMIT não existe no clone. Ajuste MLTP_COMMIT em stack/_comum.sh."
fi
git -C "$MLTP_DIR" checkout --quiet "$MLTP_COMMIT"
ok "intro-to-mltp em $(git -C "$MLTP_DIR" rev-parse --short HEAD)"

exigir_mltp

# --- 2. retenção do Tempo ---------------------------------------------------

# Armadilha número 1 do repositório oficial: tempo/tempo.yaml vem com
# `block_retention: 1h`, em dois lugares (backend_scheduler e overrides).
# Com esse valor, todo trace gravado na véspera é apagado nos primeiros
# minutos depois que o Tempo sobe no dia seguinte — e o grupo só descobre
# quando clica no trace ID na frente da turma.
TEMPO_YAML="$MLTP_DIR/tempo/tempo.yaml"
[ -f "$TEMPO_YAML" ] || morrer "não encontrei $TEMPO_YAML"

if [ ! -f "$TEMPO_YAML.original" ]; then
  cp "$TEMPO_YAML" "$TEMPO_YAML.original"
  ok "Backup criado: tempo/tempo.yaml.original"
else
  info "Backup tempo/tempo.yaml.original já existia; mantido"
fi

info "Ajustando block_retention para $RETENCAO_ALVO"
# A âncora ^[[:space:]]* é essencial: sem ela o padrão também casaria com
# `compacted_block_retention`, que é outra coisa e não deve ser mexida.
sed -i -E "s/^([[:space:]]*)block_retention:[[:space:]]*[0-9]+[a-z]+/\1block_retention: $RETENCAO_ALVO/" "$TEMPO_YAML"

ENCONTRADOS="$(grep -cE "^[[:space:]]*block_retention: $RETENCAO_ALVO" "$TEMPO_YAML" || true)"
RESTANTES="$(grep -cE "^[[:space:]]*block_retention: 1h" "$TEMPO_YAML" || true)"
if [ "$RESTANTES" != "0" ]; then
  morrer "ainda restam $RESTANTES ocorrências de 'block_retention: 1h' em $TEMPO_YAML. Edite à mão."
fi
if [ "$ENCONTRADOS" -lt 2 ]; then
  aviso "esperava 2 ocorrências de block_retention e encontrei $ENCONTRADOS."
  aviso "o tempo.yaml oficial pode ter mudado — confira o arquivo antes de gravar."
else
  ok "block_retention: $RETENCAO_ALVO em $ENCONTRADOS lugares"
fi

# --- 3. conferências de escopo ---------------------------------------------

# Armadilha número 2: o serviço k6 sobe por padrão, com restart: always.
# k6 é ferramenta de teste de carga e o enunciado veta ferramentas de teste.
# Todos os scripts daqui em diante usam --scale k6=0; este aviso serve para o
# caso de alguém rodar `docker compose up` na mão.
if grep -qE '^[[:space:]]+k6:' "$MLTP_DIR/docker-compose.yml"; then
  aviso "o serviço k6 existe no compose oficial. NUNCA suba o stack sem '--scale k6=0'."
  aviso "use sempre 'make record' / 'make restore', que já fazem isso."
fi

# O dashboard provisionado k6.json aparece na lista de dashboards do Grafana.
# Ele não deve ser aberto na demo.
if [ -f "$MLTP_DIR/grafana/definitions/k6.json" ]; then
  aviso "o dashboard 'Official k6 Test Result' é provisionado e vai aparecer na lista."
  aviso "ele não faz parte da demo — ver docs/03-escopo-e-fronteiras.md."
fi

# --- 4. imagens -------------------------------------------------------------

info "Baixando as imagens do stack (pode demorar na primeira vez)"
dc pull
ok "Imagens baixadas"

# Registra o que foi fixado, para conferência antes da apresentação.
{
  echo "# Gerado por stack/setup.sh — não editar à mão"
  echo "data_do_setup=$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "mltp_dir=$MLTP_DIR"
  echo "mltp_commit=$(git -C "$MLTP_DIR" rev-parse HEAD)"
  echo "block_retention=$RETENCAO_ALVO"
} > "$REPO_RAIZ/stack/.setup-info"

echo
ok "Ambiente pronto."
echo "   Próximo passo: 'make record' para subir o stack e começar a gravar a janela."
