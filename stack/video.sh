#!/usr/bin/env bash
# Grava o vídeo de backup da demonstração, percorrendo os sete favoritos com
# legendas sobrepostas. O vídeo é mudo de propósito: a ideia é que alguém do
# grupo narre por cima, ao vivo, se o Docker não subir na sala de aula.
#
# Pré-requisitos: Node.js 18+ e um navegador Chromium instalado (Chrome ou
# Edge). É a única parte do repositório que precisa de Node — nada da demo em
# si depende disso.
#
# Uso: ./stack/video.sh   (ou `make video`)
#
# Saída: snapshot/demo-backup.mp4 (e o .webm bruto, do qual ele é convertido).

source "$(dirname "${BASH_SOURCE[0]}")/_comum.sh"

DEPS_DIR="$REPO_RAIZ/.video"

info "Verificando pré-requisitos"
exigir_comando node "Instale o Node.js 18 ou mais novo: https://nodejs.org"
exigir_comando npm  "O npm vem junto com o Node.js."
exigir_docker
ok "Node $(node --version)"

[ -f "$SNAPSHOT_DIR/favoritos.html" ] \
  || morrer "não encontrei snapshot/favoritos.html. Rode 'make urls' antes."

# O gravador abre o Grafana de verdade: sem o stack no ar, o vídeo sai vazio.
curl -fsS --max-time 10 "http://localhost:$PORTA_GRAFANA/api/health" >/dev/null 2>&1 \
  || morrer "o Grafana não respondeu em http://localhost:$PORTA_GRAFANA. Rode 'make restore' antes."
ok "Grafana no ar"

# --- dependências -----------------------------------------------------------

# Instaladas em .video/, que está no .gitignore. Não poluem o repositório e não
# entram no caminho de quem só quer rodar a demo.
if [ ! -d "$DEPS_DIR/node_modules/playwright" ]; then
  info "Instalando playwright e ffmpeg (uma vez, em .video/)"
  mkdir -p "$DEPS_DIR"
  # SKIP_BROWSER_DOWNLOAD evita baixar ~150 MB de Chromium: o gravador usa o
  # Chrome ou o Edge que já existem na máquina.
  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    npm install --silent --no-audit --no-fund \
      --prefix "$DEPS_DIR" playwright ffmpeg-static \
    || morrer "falha ao instalar as dependências do gravador."
  ok "Dependências instaladas"
else
  info "Dependências já instaladas em .video/"
fi

# --- gravação ---------------------------------------------------------------

info "Gravando (leva uns 4 minutos; o navegador roda sem janela)"

# O script é copiado para dentro de .video/ antes de rodar. NODE_PATH não serve
# aqui: a resolução de módulos ES ignora essa variável, e o `import 'playwright'`
# só encontra o pacote se o arquivo estiver numa pasta que tenha node_modules
# acima dela. Os caminhos de entrada e saída vêm de REPO_RAIZ, então o script
# funciona de qualquer lugar.
cp "$REPO_RAIZ/stack/gravar-video.mjs" "$DEPS_DIR/gravar-video.mjs"

REPO_RAIZ="$REPO_RAIZ" node "$DEPS_DIR/gravar-video.mjs" \
  || morrer "a gravação falhou. Veja a mensagem acima."

BRUTO="$SNAPSHOT_DIR/demo-backup.webm"
[ -f "$BRUTO" ] || morrer "o gravador não produziu $BRUTO."
ok "Bruto gravado: snapshot/demo-backup.webm ($(du -h "$BRUTO" | cut -f1))"

# --- conversão --------------------------------------------------------------

# O Playwright só grava webm. MP4 é o formato que abre em qualquer player e no
# PowerPoint, que é onde este arquivo pode precisar ser usado às pressas.
FFMPEG="$DEPS_DIR/node_modules/ffmpeg-static/ffmpeg"
[ -x "$FFMPEG" ] || FFMPEG="$FFMPEG.exe"

if [ -x "$FFMPEG" ]; then
  info "Convertendo para MP4"
  "$FFMPEG" -hide_banner -loglevel error -y \
    -i "$BRUTO" \
    -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p \
    -movflags +faststart -r 25 \
    "$SNAPSHOT_DIR/demo-backup.mp4" \
    || morrer "a conversão para MP4 falhou; o .webm continua válido."
  ok "snapshot/demo-backup.mp4 ($(du -h "$SNAPSHOT_DIR/demo-backup.mp4" | cut -f1))"
else
  aviso "ffmpeg não encontrado; ficou só o .webm."
fi

echo
ok "Pronto."
echo "   Teste o arquivo no player da máquina que vai apresentar, antes do dia."
echo "   O vídeo é mudo: o combinado é narrar por cima. Ver docs/07-plano-de-contingencia.md."
