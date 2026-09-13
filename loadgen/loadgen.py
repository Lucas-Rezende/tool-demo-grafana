# Responsavel por gerar carga de trafego para a demo do Grafana.
# A linha do tempo e didatica: v1 saudavel, v2 com regressao e rollback saudavel.

import os
import random
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

import psycopg
import requests

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://grafana:grafana@postgres:5432/grafana_demo",
)
V1_URL = os.getenv("V1_URL", "http://orders-api-v1:8000")
V2_URL = os.getenv("V2_URL", "http://orders-api-v2:8000")
ROLLBACK_URL = os.getenv("ROLLBACK_URL", V1_URL)
PHASE_SECONDS = int(os.getenv("PHASE_SECONDS", "240"))
REQUEST_INTERVAL_SECONDS = float(os.getenv("REQUEST_INTERVAL_SECONDS", "0.20"))
MAX_WORKERS = int(os.getenv("MAX_WORKERS", "24"))
RESET_DATA = os.getenv("RESET_DATA", "true").lower() == "true"

ENDPOINTS = [
    ("GET", "/catalog", 0.20),
    ("POST", "/login", 0.15),
    ("POST", "/profile", 0.15),
    ("POST", "/checkout", 0.50),
]

PHASES = [
    ("v1", V1_URL, "Inicio da demo: v1 estavel recebendo trafego"),
    ("v2", V2_URL, "Deploy da versao v2 do servico de pedidos"),
    ("rollback", ROLLBACK_URL, "Rollback: trafego voltou para a versao estavel"),
]


def wait_for_service(url: str) -> None:
    while True:
        try:
            response = requests.get(f"{url}/health", timeout=2)
            if response.ok:
                return
        except requests.RequestException:
            pass
        time.sleep(2)


def prepare_database() -> None:
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            if RESET_DATA:
                cur.execute("TRUNCATE request_events, deploy_events, demo_events RESTART IDENTITY")
            cur.execute(
                """
                INSERT INTO demo_events (ts, event_type, description)
                VALUES (now(), 'start', 'Gerador de carga iniciado para a demo')
                """
            )


def mark_phase(version: str, description: str) -> None:
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO deploy_events (ts, version, description)
                VALUES (date_trunc('minute', now()), %s, %s)
                """,
                (version, description),
            )
            cur.execute(
                """
                INSERT INTO demo_events (ts, event_type, description)
                VALUES (date_trunc('minute', now()), %s, %s)
                """,
                (version, description),
            )


def pick_endpoint() -> tuple[str, str]:
    roll = random.random()
    cumulative = 0.0
    for method, endpoint, weight in ENDPOINTS:
        cumulative += weight
        if roll <= cumulative:
            return method, endpoint
    return ENDPOINTS[-1][0], ENDPOINTS[-1][1]


def current_phase(elapsed_seconds: float) -> tuple[int, str, str, str]:
    phase_index = int(elapsed_seconds // PHASE_SECONDS)
    if phase_index >= len(PHASES):
        phase_index = len(PHASES) - 1
    version, base_url, description = PHASES[phase_index]
    return phase_index, version, base_url, description


def call_api(base_url: str) -> None:
    method, endpoint = pick_endpoint()
    try:
        requests.request(method, f"{base_url}{endpoint}", timeout=4)
    except requests.RequestException as exc:
        print(f"{datetime.now().isoformat()} loadgen request failed: {exc}", flush=True)


def main() -> None:
    for _, url, _ in PHASES:
        wait_for_service(url)
    prepare_database()

    started = time.monotonic()
    marked_phases: set[int] = set()
    print("loadgen started: v1 -> v2 -> rollback", flush=True)

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        while True:
            elapsed = time.monotonic() - started
            phase_index, version, base_url, description = current_phase(elapsed)
            if phase_index not in marked_phases:
                mark_phase(version, description)
                marked_phases.add(phase_index)
                print(f"phase marker inserted: {version} - {description}", flush=True)

            executor.submit(call_api, base_url)
            time.sleep(REQUEST_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()