# Como interagir manualmente com a demo

A demo roda duas versoes da API ao mesmo tempo.

- `v1`: `http://localhost:8001`
- `v2`: `http://localhost:8002`

## Testar saude das APIs

```bash
curl http://localhost:8001/health
curl http://localhost:8002/health
```

Resultado esperado:

```json
{"status":"ok","version":"v1"}
{"status":"ok","version":"v2"}
```

## Chamar endpoints manualmente

Catalogo:

```bash
curl http://localhost:8001/catalog
curl http://localhost:8002/catalog
```

Login:

```bash
curl -X POST http://localhost:8001/login
curl -X POST http://localhost:8002/login
```

Perfil:

```bash
curl -X POST http://localhost:8001/profile
curl -X POST http://localhost:8002/profile
```

Checkout:

```bash
curl -X POST http://localhost:8001/checkout
curl -X POST http://localhost:8002/checkout
```

Na `v2`, repita o checkout algumas vezes. Ele pode demorar mais e eventualmente retornar erro 500.

## Consultar o banco diretamente

Contar eventos:

```bash
docker exec grafana-demo-postgres psql -U grafana -d grafana_demo -c "select count(*), min(ts), max(ts) from request_events;"
```

Resumo por versao e endpoint:

```bash
docker exec grafana-demo-postgres psql -U grafana -d grafana_demo -c "select * from incident_summary order by errors_5xx desc, p95_latency_ms desc;"
```

Ultimos erros:

```bash
docker exec grafana-demo-postgres psql -U grafana -d grafana_demo -c "select ts, version, endpoint, status_code, latency_ms, error_message from request_events where status_code >= 500 order by ts desc limit 10;"
```

## Comandos principais

```bash
make demo    # sobe tudo e abre o dashboard
make verify  # checa APIs e banco
make logs    # acompanha loadgen
make reset   # reinicia do zero
```