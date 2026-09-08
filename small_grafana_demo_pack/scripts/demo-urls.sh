#!/usr/bin/env bash
set -euo pipefail

cat <<'URLS'
Grafana:
http://localhost:3000/d/maintenance-demo/demo-grafana-manutencao?orgId=1&from=now-15m&to=now&timezone=browser&var-endpoint=$__all&var-version=$__all&refresh=10s

Orders API v1:
http://localhost:8001/health

Orders API v2:
http://localhost:8002/health
URLS
