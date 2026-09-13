#!/usr/bin/env bash
set -euo pipefail

DASHBOARD_URL='http://localhost:3000/d/maintenance-demo/demo-grafana-manutencao?orgId=1&from=now-15m&to=now&timezone=browser&var-endpoint=$__all&var-version=$__all&refresh=10s'

wait_for_url() {
  local name="$1"
  local url="$2"
  local attempts="${3:-60}"

  printf 'Aguardando %s' "$name"
  for _ in $(seq 1 "$attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      printf ' ok\n'
      return 0
    fi
    printf '.'
    sleep 2
  done

  printf '\n'
  echo "Timeout aguardando $name em $url"
  return 1
}

open_url() {
  local url="$1"

  if command -v wslview >/dev/null 2>&1; then
    wslview "$url" >/dev/null 2>&1 &
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "Start-Process '$url'" >/dev/null 2>&1
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  else
    echo "Nao consegui abrir o navegador automaticamente. Abra manualmente:"
    echo "$url"
  fi
}

echo 'Subindo containers da demo...'
docker compose up -d --build

echo
wait_for_url 'orders-api-v1' 'http://localhost:8001/health' 45
wait_for_url 'orders-api-v2' 'http://localhost:8002/health' 45
wait_for_url 'Grafana' 'http://localhost:3000/api/health' 60

echo
echo 'Abrindo dashboard no navegador...'
open_url "$DASHBOARD_URL"

echo
echo 'Demo no ar.'
echo 'Dashboard:'
echo "$DASHBOARD_URL"
echo
echo 'Dica: espere cerca de 2 minutos para o loadgen marcar o deploy da v2.'
echo 'Depois filtre version=v2 e endpoint=/checkout.'