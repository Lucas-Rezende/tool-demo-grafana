.PHONY: help demo up open verify logs down reset ps clean-containers

DASHBOARD_URL := http://localhost:3000/d/maintenance-demo/demo-grafana-manutencao?orgId=1&from=now-15m&to=now&timezone=browser&var-endpoint=$$__all&var-version=$$__all&refresh=10s
DEMO_CONTAINERS := grafana-demo grafana-demo-postgres grafana-demo-orders-api-v1 grafana-demo-orders-api-v2 grafana-demo-loadgen

help:
	@echo "Comandos disponiveis:"
	@echo "  make demo    sobe tudo, espera os servicos e abre o dashboard"
	@echo "  make up      sobe os containers em background"
	@echo "  make open    abre o dashboard"
	@echo "  make verify  verifica APIs e resumo do incidente"
	@echo "  make logs    acompanha logs do loadgen"
	@echo "  make ps      lista containers"
	@echo "  make down    para e remove containers da demo"
	@echo "  make reset   encerra/remova containers antigos, apaga volumes e reinicia do zero"

demo:
	@bash scripts/demo.sh

up:
	docker compose up -d --build

open:
	@if command -v wslview >/dev/null 2>&1; then \
		wslview '$(DASHBOARD_URL)'; \
	elif command -v powershell.exe >/dev/null 2>&1; then \
		powershell.exe -NoProfile -Command "Start-Process '$(DASHBOARD_URL)'" >/dev/null 2>&1; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open '$(DASHBOARD_URL)' >/dev/null 2>&1; \
	else \
		echo 'Abra manualmente:'; \
		echo '$(DASHBOARD_URL)'; \
	fi

verify:
	@bash scripts/verify.sh

logs:
	docker compose logs -f loadgen

ps:
	docker compose ps

clean-containers:
	-docker compose down -v --remove-orphans
	-docker rm -f $(DEMO_CONTAINERS) 2>/dev/null || true

down: clean-containers

reset: clean-containers
	docker compose up -d --build