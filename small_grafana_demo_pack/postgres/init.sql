-- Schema da demo de Grafana em Manutencao de Software.
-- A aplicacao orders-api grava eventos reais nesta tabela enquanto o loadgen roda.

CREATE TABLE IF NOT EXISTS request_events (
  id BIGSERIAL PRIMARY KEY,
  ts TIMESTAMPTZ NOT NULL DEFAULT now(),
  service TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  method TEXT NOT NULL,
  version TEXT NOT NULL,
  status_code INT NOT NULL,
  latency_ms INT NOT NULL,
  level TEXT NOT NULL,
  error_message TEXT,
  trace_id TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_request_events_ts ON request_events(ts);
CREATE INDEX IF NOT EXISTS idx_request_events_endpoint ON request_events(endpoint);
CREATE INDEX IF NOT EXISTS idx_request_events_version ON request_events(version);
CREATE INDEX IF NOT EXISTS idx_request_events_status_code ON request_events(status_code);

CREATE TABLE IF NOT EXISTS deploy_events (
  id BIGSERIAL PRIMARY KEY,
  ts TIMESTAMPTZ NOT NULL DEFAULT now(),
  version TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS demo_events (
  id BIGSERIAL PRIMARY KEY,
  ts TIMESTAMPTZ NOT NULL DEFAULT now(),
  event_type TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE OR REPLACE VIEW minute_kpis AS
SELECT
  date_trunc('minute', ts) AS minute,
  endpoint,
  version,
  count(*) AS requests,
  100.0 * count(*) FILTER (WHERE status_code >= 500) / NULLIF(count(*), 0) AS error_rate_pct,
  percentile_cont(0.95) WITHIN GROUP (ORDER BY latency_ms) AS p95_latency_ms
FROM request_events
GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW incident_summary AS
SELECT
  version,
  endpoint,
  count(*) AS requests,
  count(*) FILTER (WHERE status_code >= 500) AS errors_5xx,
  round((100.0 * count(*) FILTER (WHERE status_code >= 500) / NULLIF(count(*), 0))::numeric, 2) AS error_rate_pct,
  round(percentile_cont(0.95) WITHIN GROUP (ORDER BY latency_ms)::numeric, 0) AS p95_latency_ms
FROM request_events
GROUP BY 1, 2
ORDER BY version, endpoint;
