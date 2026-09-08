#!/usr/bin/env bash
set -euo pipefail

echo "== Containers =="
docker compose ps

echo
echo "== Saude das APIs =="
curl -fsS http://localhost:8001/health
echo
curl -fsS http://localhost:8002/health
echo

echo
echo "== Resumo do incidente =="
docker exec grafana-demo-postgres psql -U grafana -d grafana_demo -c "select version, endpoint, requests, errors_5xx, error_rate_pct, p95_latency_ms from incident_summary order by errors_5xx desc, p95_latency_ms desc;"

echo
echo "== Ultimos erros =="
docker exec grafana-demo-postgres psql -U grafana -d grafana_demo -c "select to_char(ts, 'HH24:MI:SS') as time, version, endpoint, status_code, latency_ms, error_message from request_events where status_code >= 500 order by ts desc limit 8;"
