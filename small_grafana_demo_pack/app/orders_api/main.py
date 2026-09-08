import hashlib
import os
import random
import time
from datetime import UTC, datetime

import psycopg
from fastapi import FastAPI, Response


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://grafana:grafana@postgres:5432/grafana_demo",
)
APP_VERSION = os.getenv("APP_VERSION", "v1")
BUG_ENABLED = os.getenv("BUG_ENABLED", "false").lower() == "true"
SERVICE_NAME = "orders-api"

app = FastAPI(title="Orders API - Grafana maintenance demo")


def record_event(
    endpoint: str,
    method: str,
    status_code: int,
    latency_ms: int,
    error_message: str | None = None,
) -> None:
    level = "ERROR" if status_code >= 500 else "WARN" if status_code >= 400 else "INFO"
    trace_seed = f"{datetime.now(UTC).isoformat()}:{endpoint}:{APP_VERSION}:{latency_ms}:{random.random()}"
    trace_id = hashlib.md5(trace_seed.encode("utf-8")).hexdigest()

    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO request_events (
                  ts, service, endpoint, method, version, status_code,
                  latency_ms, level, error_message, trace_id
                )
                VALUES (now(), %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    SERVICE_NAME,
                    endpoint,
                    method,
                    APP_VERSION,
                    status_code,
                    latency_ms,
                    level,
                    error_message,
                    trace_id,
                ),
            )


def simulate_work(endpoint: str) -> tuple[int, str | None]:
    if endpoint == "/checkout" and APP_VERSION == "v2" and BUG_ENABLED:
        time.sleep(random.uniform(0.85, 1.9))
        if random.random() < 0.14:
            return 500, "database connection pool exhausted"
        return 200, None

    if endpoint == "/checkout":
        time.sleep(random.uniform(0.12, 0.32))
    elif endpoint == "/catalog":
        time.sleep(random.uniform(0.05, 0.16))
    elif endpoint == "/login":
        time.sleep(random.uniform(0.08, 0.22))
        if random.random() < 0.02:
            return 401, "invalid credentials"
    else:
        time.sleep(random.uniform(0.06, 0.18))

    if random.random() < 0.006:
        return 500, "unexpected upstream error"
    return 200, None


def handle(endpoint: str, method: str, response: Response) -> dict[str, object]:
    started = time.perf_counter()
    status_code, error_message = simulate_work(endpoint)
    latency_ms = int((time.perf_counter() - started) * 1000)
    record_event(endpoint, method, status_code, latency_ms, error_message)
    response.status_code = status_code

    return {
        "service": SERVICE_NAME,
        "version": APP_VERSION,
        "endpoint": endpoint,
        "status": status_code,
        "latency_ms": latency_ms,
        "error": error_message,
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "version": APP_VERSION}


@app.get("/catalog")
def catalog(response: Response) -> dict[str, object]:
    payload = handle("/catalog", "GET", response)
    payload["items"] = ["notebook", "monitor", "keyboard", "mouse"]
    return payload


@app.post("/login")
def login(response: Response) -> dict[str, object]:
    return handle("/login", "POST", response)


@app.post("/profile")
def profile(response: Response) -> dict[str, object]:
    return handle("/profile", "POST", response)


@app.post("/checkout")
def checkout(response: Response) -> dict[str, object]:
    return handle("/checkout", "POST", response)
