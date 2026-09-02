#!/usr/bin/env bash
# Funções e variáveis compartilhadas por todos os scripts de stack/.
# Não execute este arquivo diretamente: ele é carregado com `source`.

set -euo pipefail

# No Git Bash / MSYS o shell reescreve argumentos que parecem caminhos POSIX
# antes de entregá-los ao binário do Windows. Para o docker.exe isso é bom em
# `-f /caminho/docker-compose.yml` (o arquivo é do host) e péssimo em
# `-v volume:/dados` (o /dados é do container e vira C:/Program Files/Git/dados).
# Por isso a conversão NUNCA é desligada globalmente — desligá-la faria o
# `git clone` deste mesmo script escrever em D:\d\... Só as chamadas que
# passam caminhos de container usam docker_container() abaixo.
docker_container() {
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' docker "$@"
}

# Raiz do repositório do trabalho (a pasta que contém stack/ e docs/).
REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Onde vive o clone do repositório oficial da Grafana. Pode ser sobrescrito:
#   MLTP_DIR=/outro/caminho ./stack/setup.sh
MLTP_DIR="${MLTP_DIR:-$REPO_RAIZ/intro-to-mltp}"

# Pasta dos tarballs do dataset congelado. Não vai para o Git (ver .gitignore).
SNAPSHOT_DIR="${SNAPSHOT_DIR:-$REPO_RAIZ/snapshot}"

# Nome do projeto Compose. Está fixado no campo `name:` do docker-compose.yml
# oficial, e é o prefixo de todos os volumes nomeados.
PROJETO="grafana-intro-to-mltp"

# Commit do intro-to-mltp usado como referência. O repositório oficial muda com
# frequência; fixar o commit é o que torna a demo reprodutível entre ensaios.
# Atualize aqui e rode ./stack/setup.sh de novo se precisar de uma versão nova.
MLTP_COMMIT="${MLTP_COMMIT:-25a92a16f9b6fd2db001c51e07b9603decc5aefd}"
MLTP_URL="https://github.com/grafana/intro-to-mltp.git"

# Volumes que precisam ser congelados. Atenção:
#   - grafana e postgres já são DECLARADOS no compose oficial;
#   - loki, tempo e mimir são criados pelo nosso docker-compose.override.yml.
# Sem os três últimos, os dados vivem na camada gravável do container e somem
# em qualquer `docker compose down`.
VOLUMES=(grafana postgres loki tempo mimir)

# Portas expostas pelo stack (usadas por record.sh e verify.sh).
PORTA_GRAFANA=3000
PORTA_APP=3001
PORTA_MIMIR=9009
PORTA_LOKI=3100
PORTA_TEMPO=3200

# --- saída ------------------------------------------------------------------

VERDE=$'\033[32m'; VERMELHO=$'\033[31m'; AMARELO=$'\033[33m'; NEGRITO=$'\033[1m'; RESET=$'\033[0m'

info()  { printf '%s==>%s %s\n' "$NEGRITO" "$RESET" "$*"; }
ok()    { printf '%s  OK %s %s\n' "$VERDE" "$RESET" "$*"; }
aviso() { printf '%s  !! %s %s\n' "$AMARELO" "$RESET" "$*"; }
erro()  { printf '%s ERRO%s %s\n' "$VERMELHO" "$RESET" "$*" >&2; }

morrer() { erro "$*"; exit 1; }

# --- pré-condições ----------------------------------------------------------

exigir_comando() {
  command -v "$1" >/dev/null 2>&1 || morrer "comando '$1' não encontrado no PATH. $2"
}

exigir_docker() {
  exigir_comando docker "Instale o Docker Desktop (ou o Docker Engine) antes de continuar."
  docker info >/dev/null 2>&1 \
    || morrer "o daemon do Docker não está respondendo. Abra o Docker Desktop e tente de novo."
  docker compose version >/dev/null 2>&1 \
    || morrer "o plugin 'docker compose' (v2) não está disponível. 'docker-compose' v1 não serve."
}

# Confirma que MLTP_DIR é mesmo um clone do intro-to-mltp, e não uma pasta
# qualquer. Um erro aqui destruiria volumes de outro projeto lá na frente.
exigir_mltp() {
  [ -d "$MLTP_DIR" ] \
    || morrer "não encontrei '$MLTP_DIR'. Rode 'make setup' primeiro (ele clona o repositório oficial)."
  [ -f "$MLTP_DIR/docker-compose.yml" ] \
    || morrer "'$MLTP_DIR' existe mas não tem docker-compose.yml. Não parece um clone do intro-to-mltp."
  grep -q "^name: $PROJETO" "$MLTP_DIR/docker-compose.yml" \
    || morrer "'$MLTP_DIR/docker-compose.yml' não declara 'name: $PROJETO'. O repositório oficial mudou; confira docs/04-demo-reprodutivel.md antes de prosseguir."
  [ -f "$REPO_RAIZ/stack/docker-compose.override.yml" ] \
    || morrer "faltando stack/docker-compose.override.yml no repositório do trabalho."
}

# --- docker compose ---------------------------------------------------------

# Todo comando compose passa por aqui. Isso garante três coisas de uma vez:
#   1. o compose oficial vem primeiro (define o project directory e o nome);
#   2. o nosso override é sempre aplicado (volumes nomeados que faltam);
#   3. ninguém esquece de um dos dois arquivos em uma chamada manual.
dc() {
  docker compose \
    -f "$MLTP_DIR/docker-compose.yml" \
    -f "$REPO_RAIZ/stack/docker-compose.override.yml" \
    "$@"
}

# Sobe o stack SEM o k6. O k6 é ferramenta de teste de carga e está fora do
# escopo do trabalho (ver docs/03-escopo-e-fronteiras.md). Ele tem
# `restart: always` no compose oficial, então subir sem --scale k6=0 o deixa
# rodando para sempre em segundo plano.
subir_sem_k6() {
  preparar_volumes
  dc up -d --scale k6=0 "$@"
}

# --- volumes ----------------------------------------------------------------

vol() { printf '%s_%s' "$PROJETO" "$1"; }

# Dono que cada volume precisa ter DENTRO do container.
#
# Normalmente não é preciso mexer nisso: quando o caminho já existe na imagem,
# o Docker copia conteúdo e dono da imagem para o volume vazio. É o que
# acontece com /loki (uid 10001), /var/lib/grafana (uid 472) e
# /var/lib/postgresql. O Mimir roda como root e também não se importa.
#
# O Tempo é a exceção e custa caro descobrir tarde: /tmp/tempo NÃO existe na
# imagem (só /tmp existe, com 1777). O volume nomeado nasce root:root 0755, o
# processo roda como 10001 e o Tempo morre no boot com
#   "failed to create store: mkdir /tmp/tempo/blocks: permission denied".
# O stack sobe, dashboard e logs funcionam, e só o trace — o clímax da
# apresentação — não existe.
#
# Lista simples em vez de array associativo de propósito: o bash padrão do
# macOS ainda é o 3.2, que não tem `declare -A`.
DONOS_A_AJUSTAR="tempo:10001:10001"

# Cria os volumes que faltam e conserta o dono. Precisa rodar ANTES do `up`.
preparar_volumes() {
  local v item nome dono
  for v in "${VOLUMES[@]}"; do
    volume_existe "$v" || docker volume create "$(vol "$v")" >/dev/null
  done
  for item in $DONOS_A_AJUSTAR; do
    nome="${item%%:*}"
    dono="${item#*:}"
    volume_existe "$nome" || continue
    docker_container run --rm -v "$(vol "$nome"):/dados" alpine:3.22 \
      chown -R "$dono" /dados
  done
}

volume_existe() { docker volume inspect "$(vol "$1")" >/dev/null 2>&1; }

# Exporta um volume para um tarball via stdout. Sem bind mount de propósito:
# bind mounts quebram com acentos no caminho e com a tradução de caminhos do
# Git Bash no Windows. Streaming pelo stdout funciona igual nos três sistemas.
exportar_volume() {
  local nome="$1" destino="$2"
  docker_container run --rm -v "$(vol "$nome"):/dados:ro" alpine:3.22 \
    tar czf - -C /dados . > "$destino"
}

importar_volume() {
  local nome="$1" origem="$2"
  docker_container run --rm -i -v "$(vol "$nome"):/dados" alpine:3.22 \
    tar xzf - -C /dados < "$origem"
}

# --- tempo ------------------------------------------------------------------

# Epoch em milissegundos. É o formato que o Grafana usa em `from=`/`to=` na URL
# e o que verify.sh consome. `date +%s%3N` não existe no macOS, daí o fallback.
agora_ms() {
  # O `date` do macOS não entende %3N e devolve algo como "17883105473N".
  # Por isso exigimos exatamente 13 dígitos antes de aceitar o resultado.
  local t
  t="$(date +%s%3N 2>/dev/null || true)"
  case "$t" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) printf '%s' "$t" ;;
    *) printf '%s000' "$(date +%s)" ;;
  esac
}

ms_para_legivel() {
  local ms="$1"
  # O sed final tira espaços à direita: no Git Bash o %Z costuma vir vazio.
  { date -d "@$(( ms / 1000 ))" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
      || date -r "$(( ms / 1000 ))" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null \
      || printf '(epoch %s)' "$ms"; } | sed 's/[[:space:]]*$//'
}
