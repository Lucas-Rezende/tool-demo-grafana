# Demo Grafana - manutencao corretiva em uma API real pequena

Esta pasta contem uma demo pronta para apresentar Grafana como ferramenta de apoio a manutencao de software.

A diferenca para uma demo puramente sintetica: aqui existe um pequeno software rodando de verdade. A API `orders-api` recebe requisicoes reais, grava eventos no PostgreSQL, e o Grafana mostra quando uma nova versao introduz um problema.

## Historia da demo

Um servico de pedidos funcionava normalmente na versao `v1`. Depois de um deploy para `v2`, usuarios comecam a reclamar que o checkout ficou lento e falha algumas vezes.

A pergunta da apresentacao e:

> Como o Grafana ajuda a equipe de manutencao a sair de uma reclamacao vaga para uma hipotese tecnica de correcao?

## Arquitetura

```text
loadgen
  |
  | primeiro manda trafego para v1
  | depois de 2 minutos registra um deploy e passa a mandar trafego para v2
  v
orders-api-v1        orders-api-v2
sem bug              com bug no /checkout
  |                    |
  +---------+----------+
            |
            v
        PostgreSQL
        request_events
        deploy_events
            |
            v
          Grafana
```

Servicos:

- `postgres`: banco da demo.
- `orders-api-v1`: API sem bug, exposta em `http://localhost:8001`.
- `orders-api-v2`: mesma API, mas com bug no `/checkout`, exposta em `http://localhost:8002`.
- `loadgen`: simula usuarios acessando catalogo, login, perfil e checkout.
- `grafana`: dashboard em `http://localhost:3000`.

## Onde esta o bug

Arquivo: `app/orders_api/main.py`.

Na `v2`, somente o endpoint `/checkout` fica mais lento e as vezes retorna erro 500:

```text
database connection pool exhausted
```

Essa mensagem simula um bug comum depois de mudancas em software: conexoes com banco sendo usadas de forma ineficiente, vazamento de conexao, pool mal dimensionado ou transacao longa demais.

## Como rodar

Na pasta da demo:

```bash
docker compose up -d --build
```

Espere 30 a 60 segundos para a primeira carga comecar.

Abra o Grafana:

```text
http://localhost:3000/d/maintenance-demo/demo-grafana-manutencao?orgId=1&from=now-15m&to=now&timezone=browser&var-endpoint=$__all&var-version=$__all&refresh=10s
```

Login, se solicitado:

```text
usuario: admin
senha: admin
```

O loadgen funciona assim:

- Nos primeiros 2 minutos: envia trafego para `v1`.
- Depois de 2 minutos: insere o evento de deploy da `v2`.
- A partir dai: envia trafego para `v2`, onde o `/checkout` tem regressao.

## Como verificar se esta tudo OK

Rode:

```bash
./scripts/verify.sh
```

Se o WSL reclamar de permissao, rode a forma equivalente:

```bash
bash scripts/verify.sh
```

O resultado esperado e:

- os containers `postgres`, `grafana`, `orders-api-v1`, `orders-api-v2` e `loadgen` rodando;
- as duas APIs respondendo no endpoint `/health`;
- a tabela `incident_summary` mostrando maior latencia e mais erros em `v2 /checkout`.

Comandos manuais úteis:

```bash
docker compose ps
docker compose logs -f loadgen
docker compose logs -f grafana
```

Para reiniciar a apresentacao do zero:

```bash
docker compose down -v
docker compose up -d --build
```

## Fluxo Básico do que discutir
1. Detectar anomalia
   A taxa de erro e a latência subiram.

2. Relacionar com uma mudança
   A subida começa depois do deploy da v2.

3. Reduzir o escopo
   Não é o sistema inteiro: é principalmente /checkout.

4. Priorizar impacto
   Checkout é fluxo crítico, então isso vira prioridade.

5. Apoiar hipótese técnica
   A mensagem "database connection pool exhausted" aponta para banco/conexões.

6. Acompanhar correção
   Depois de corrigir ou fazer rollback, o Grafana mostraria erro e latência voltando ao normal.
