#!/usr/bin/env bash
# Gera as URLs congeladas da demo e um arquivo de favoritos importável no
# navegador. Rode com o stack no ar: ele consulta o Grafana para descobrir o
# UID da regra de alerta sintética.
#
# Uso:
#   ./stack/urls.sh                              usa snapshot/janela.env
#   ENDPOINT=/unicorn TRACE=abc123 ./stack/urls.sh
#
# Variáveis reconhecidas:
#   ENDPOINT  endpoint fixado no favorito 2, para mostrar que o erro NAO se
#             concentra nele (ex.: /owlbear)
#   TRACE     trace ID aberto no favorito 5
#
# Saída:
#   - as sete URLs no terminal, na ordem do roteiro;
#   - snapshot/favoritos.html, importável no Chrome, Edge ou Firefox.

source "$(dirname "${BASH_SOURCE[0]}")/_comum.sh"

exigir_comando curl "Instale o curl (vem com o Git for Windows)."

[ -f "$SNAPSHOT_DIR/janela.env" ] \
  || morrer "não encontrei snapshot/janela.env. Rode 'make freeze' antes."
# shellcheck disable=SC1091
source "$SNAPSHOT_DIR/janela.env"

INICIO="${JANELA_INICIO_MS:-}"
FIM="${JANELA_FIM_MS:-}"
case "$INICIO$FIM" in
  *[!0-9]*|"") morrer "janela inválida em snapshot/janela.env." ;;
esac

ENDPOINT="${ENDPOINT:-}"
TRACE="${TRACE:-}"
GRAFANA="http://localhost:$PORTA_GRAFANA"
DASHBOARD="/d/mlt-demo/mlt-demo-tool-demo-dcc-ufmg"

# --- codificação de URL -----------------------------------------------------

# Codificador em bash puro. Delegar isso ao curl (--data-urlencode mais
# %{url_effective}) parece mais simples e não é: no Git Bash a tradução de
# caminhos transforma ENDPOINT=/unicorn em "C:/Program Files/Git/unicorn"
# antes de o curl ver o argumento. Usar python resolveria, mas adicionaria uma
# dependência que não está garantida na máquina de ninguém do grupo.
#
# LC_ALL=C faz a iteração ser por byte e não por caractere, que é o que a
# codificação percent exige.
urlenc() {
  local s="$1" out="" i c
  local LC_ALL=C
  for (( i = 0; i < ${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out="$out$c" ;;
      *)               out="$out$(printf '%%%02X' "'$c")" ;;
    esac
  done
  printf '%s' "$out"
}

# url <caminho> <chave=valor>...
url() {
  local caminho="$1"; shift
  local qs="" par chave valor
  for par in "$@"; do
    chave="${par%%=*}"
    valor="${par#*=}"
    [ -n "$qs" ] && qs="$qs&"
    qs="$qs$chave=$(urlenc "$valor")"
  done
  printf '%s%s?%s' "$GRAFANA" "$caminho" "$qs"
}

# Escapa aspas e barras invertidas para embutir uma consulta dentro do JSON.
json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# UID da regra sintética, descoberto pelo título. Sem o stack no ar, o favorito
# 7 cai para a lista geral de alertas.
uid_regra_sintetica() {
  curl -fsS --max-time 10 "$GRAFANA/api/v1/provisioning/alert-rules" 2>/dev/null \
    | tr '}' '\n' \
    | grep -i 'SINT' \
    | grep -oE '"uid":"[^"]+"' \
    | head -1 \
    | cut -d'"' -f4
}

# --- consultas usadas na demo ----------------------------------------------

LOGQL_ERROS='{job="alloy"} | logfmt | status="Error"'
# Esta é a consulta que derruba a segunda hipótese da demo: ela desenha a
# mediana da duração do span `requester` separada por status. As duas linhas
# se sobrepõem, o que prova que as requisições que falham NÃO são as lentas.
LOGQL_GRAFICO='quantile_over_time(0.5, {job="alloy"} | logfmt | svc="mythical-requester" | status=~"Ok|Error" | unwrap duration(dur) [5m]) by (status)'

# O Explore carrega o estado inteiro no parâmetro `panes`, em JSON. O intervalo
# vai como epoch em milissegundos, em string, exatamente como o Grafana grava.
pane_loki() {
  printf '{"demo":{"datasource":"loki","queries":[{"refId":"A","datasource":{"type":"loki","uid":"loki"},"editorMode":"code","expr":"%s","queryType":"range"}],"range":{"from":"%s","to":"%s"}}}' \
    "$(json_str "$1")" "$INICIO" "$FIM"
}

pane_tempo() {
  printf '{"demo":{"datasource":"tempo","queries":[{"refId":"A","datasource":{"type":"tempo","uid":"tempo"},"queryType":"traceql","query":"%s"}],"range":{"from":"%s","to":"%s"}}}' \
    "$(json_str "$1")" "$INICIO" "$FIM"
}

# --- montagem ---------------------------------------------------------------

info "Janela: $INICIO .. $FIM  ($(ms_para_legivel "$INICIO") a $(ms_para_legivel "$FIM"))"

U1="$(url "$DASHBOARD" "orgId=1" "from=$INICIO" "to=$FIM")"

if [ -n "$ENDPOINT" ]; then
  U2="$(url "$DASHBOARD" "orgId=1" "from=$INICIO" "to=$FIM" \
           "var-httpEndpoint=$ENDPOINT" \
           'var-httpStatus=$__all' \
           'var-serviceVersion=$__all')"
else
  aviso "ENDPOINT não informado; o favorito 2 sai sem o filtro de endpoint."
  U2="$U1"
fi

U3="$(url /explore "orgId=1" "schemaVersion=1" "panes=$(pane_loki "$LOGQL_ERROS")")"
U4="$(url /explore "orgId=1" "schemaVersion=1" "panes=$(pane_loki "$LOGQL_GRAFICO")")"

if [ -n "$TRACE" ]; then
  U5="$(url /explore "orgId=1" "schemaVersion=1" "panes=$(pane_tempo "$TRACE")")"
else
  aviso "TRACE não informado; o favorito 5 sai na busca por spans com erro."
  U5="$(url /explore "orgId=1" "schemaVersion=1" "panes=$(pane_tempo '{status=error}')")"
fi

# view=list em vez do agrupamento padrão: a visão agrupada abre com a pasta
# recolhida e obrigaria a pessoa 3 a expandir o grupo no projetor. Com
# view=list as duas regras aparecem de cara, com o resumo de cada uma.
U6="$(url /alerting/list "orgId=1" "view=list")"

UID_SINT="$(uid_regra_sintetica || true)"
if [ -n "$UID_SINT" ]; then
  U7="$(url "/alerting/grafana/$UID_SINT/view" "orgId=1")"
else
  aviso "não achei a regra sintética pela API; o favorito 7 aponta para a lista."
  U7="$U6"
fi

# --- saída ------------------------------------------------------------------

TITULOS=(
  "1. Abertura — MLT Demo, janela completa"
  "2. Abertura — MLT Demo filtrado num endpoint (derruba a hipótese)"
  "3. Logs — Explore/Loki, erros"
  "4. Logs — Explore/Loki, duração Ok vs Error (as linhas se sobrepõem)"
  "5. Traces — Explore/Tempo, cascata de spans"
  "6. Alertas — lista de regras"
  "7. Alertas — regra sintética, transição de estado"
)
URLS=("$U1" "$U2" "$U3" "$U4" "$U5" "$U6" "$U7")

echo
for i in 0 1 2 3 4 5 6; do
  printf '%s%s%s\n%s\n\n' "$NEGRITO" "${TITULOS[$i]}" "$RESET" "${URLS[$i]}"
done

DESTINO="$SNAPSHOT_DIR/favoritos.html"
{
  echo '<!DOCTYPE NETSCAPE-Bookmark-file-1>'
  echo '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">'
  echo '<TITLE>Bookmarks</TITLE>'
  echo '<H1>Bookmarks</H1>'
  echo '<DL><p>'
  echo '    <DT><H3>Tool Demo — Grafana</H3>'
  echo '    <DL><p>'
  for i in 0 1 2 3 4 5 6; do
    printf '        <DT><A HREF="%s">%s</A>\n' "${URLS[$i]}" "${TITULOS[$i]}"
  done
  echo '    </DL><p>'
  echo '</DL><p>'
} > "$DESTINO"

ok "Favoritos gravados em snapshot/favoritos.html"
echo "   Importe no navegador: Favoritos > Gerenciar > Importar de arquivo HTML."
echo "   As mesmas URLs devem ser coladas em stack/JANELA.md, seção 3."
