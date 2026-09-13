# O que cada arquivo faz

## Arquivos de execucao

### `docker-compose.yml`

Sobe todo o ambiente da demo:

- PostgreSQL;
- Grafana;
- `orders-api-v1`;
- `orders-api-v2`;
- `loadgen`.

Tambem define portas, variaveis de ambiente, dependencias entre containers e volumes.

### `Makefile`

Cria comandos curtos para operar a demo:

- `make demo`: sobe tudo, espera APIs/Grafana e abre o dashboard;
- `make verify`: verifica se os containers e dados estao funcionando;
- `make logs`: acompanha logs do `loadgen`;
- `make reset`: reinicia a demo do zero, apagando o volume do banco.

### `scripts/demo.sh`

Script chamado por `make demo`. Ele:

1. roda `docker compose up -d --build`;
2. espera `orders-api-v1`, `orders-api-v2` e Grafana responderem;
3. tenta abrir o dashboard no navegador;
4. imprime a URL caso nao consiga abrir automaticamente.

### `scripts/verify.sh`

Script chamado por `make verify`. Ele lista containers, testa `/health` das duas APIs, consulta o resumo do incidente no PostgreSQL e mostra os ultimos erros.

## API

### `app/orders_api/main.py`

Implementa a API de pedidos em FastAPI.

Endpoints principais:

- `GET /health`: checagem de saude da versao;
- `GET /catalog`: simula consulta ao catalogo;
- `POST /login`: simula login;
- `POST /profile`: simula acesso ao perfil;
- `POST /checkout`: simula finalizacao de pedido.

A regressao esta nesse arquivo: quando `APP_VERSION=v2` e `BUG_ENABLED=true`, o endpoint `/checkout` demora mais e as vezes retorna erro 500 com a mensagem `database connection pool exhausted`.

### `app/Dockerfile` e `app/requirements.txt`

Constroem a imagem Python da API e instalam dependencias como FastAPI, Uvicorn e psycopg.

## Gerador de carga

### `loadgen/loadgen.py`

Simula usuarios chamando a API. O comportamento e:

1. espera as duas versoes da API ficarem saudaveis;
2. limpa as tabelas de eventos;
3. envia trafego para `v1` por 2 minutos;
4. registra o deploy da `v2`;
5. passa a enviar trafego para `v2`.

Ele escolhe endpoints com pesos diferentes. O `/checkout` recebe mais trafego porque e o fluxo critico da demo.

### `loadgen/Dockerfile` e `loadgen/requirements.txt`

Constroem a imagem Python do gerador de carga e instalam dependencias como `requests` e `psycopg`.

## Banco de dados

### `postgres/init.sql`

Cria as tabelas e views:

- `request_events`: eventos de cada requisicao;
- `deploy_events`: eventos de deploy usados como anotacao no Grafana;
- `demo_events`: eventos auxiliares da demo;
- `minute_kpis`: KPIs por minuto;
- `incident_summary`: resumo por versao e endpoint.

## Grafana

### `grafana/provisioning/datasources/postgres.yml`

Configura automaticamente o PostgreSQL como fonte de dados do Grafana.

### `grafana/provisioning/dashboards/dashboards.yml`

Configura o provisionamento automatico dos dashboards.

### `grafana/dashboards/maintenance-demo.json`

Define o dashboard da demo: paineis, consultas SQL, filtros `endpoint` e `version`, e anotacao de deploy.

## Materiais auxiliares

### `assets/`

Contem imagens estaticas para plano B da apresentacao.

### `dataset/`

Contem descricao dos dados e uma amostra CSV para explicacao offline.