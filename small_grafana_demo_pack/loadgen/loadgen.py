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
SWITCH_AFTER_SECONDS = int(os.getenv("SWITCH_AFTER_SECONDS", "120"))
REQUEST_INTERVAL_SECONDS = float(os.getenv("REQUEST_INTERVAL_SECONDS", "0.45"))
MAX_WORKERS = int(os.getenv("MAX_WORKERS", "12"))
RESET_DATA = os.getenv("RESET_DATA", "true").lower() == "true"

ENDPOINTS = [
    ("GET", "/catalog", 0.26),
    ("POST", "/login", 0.17),
    ("POST", "/profile", 0.17),
    ("POST", "/checkout", 0.40),
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


def mark_deploy_once() -> None:
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO deploy_events (ts, version, description)
                VALUES (now(), 'v2', 'Deploy da versao v2 do servico de pedidos')
                """
            )
            cur.execute(
                """
                INSERT INTO demo_events (ts, event_type, description)
                VALUES (now(), 'deploy', 'Trafego migrado de v1 para v2')
                """
            )


def pick_endpoint() -> tuple[str, str]:
    roll = random.random()
    cumulative = 0.0
    for method, endpoint, weight in ENDPOINTS:
        cumulative += weight
        if roll <= cumulative:
            return method, endpoint
    return ENDPOINTS[-1][0], ENDPOINTS[-1][1]


def call_api(base_url: str) -> None:
    method, endpoint = pick_endpoint()
    try:
        requests.request(method, f"{base_url}{endpoint}", timeout=4)
    except requests.RequestException as exc:
        print(f"{datetime.now().isoformat()} loadgen request failed: {exc}", flush=True)


def main() -> None:
    wait_for_service(V1_URL)
    wait_for_service(V2_URL)
    prepare_database()

    started = time.monotonic()
    deploy_marked = False
    print("loadgen started: traffic begins on v1 and later migrates to v2", flush=True)

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        while True:
            elapsed = time.monotonic() - started
            if elapsed >= SWITCH_AFTER_SECONDS:
                if not deploy_marked:
                    mark_deploy_once()
                    deploy_marked = True
                    print("deploy marker inserted: now sending traffic to v2", flush=True)
                base_url = V2_URL
            else:
                base_url = V1_URL

            executor.submit(call_api, base_url)
            time.sleep(REQUEST_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
