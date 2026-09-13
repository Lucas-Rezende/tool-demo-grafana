# Como os dados sao gerados

Os dados do dashboard sao produzidos durante a execucao da demo. Eles nao sao apenas um CSV importado.

## Fluxo de geracao

```text
loadgen -> orders-api-v1/v2 -> PostgreSQL -> Grafana
```

1. O `loadgen` faz requisicoes HTTP para a API.
2. A API mede a latencia, decide o status HTTP e grava um evento no PostgreSQL.
3. O Grafana consulta o PostgreSQL para montar os paineis.

## O que e gravado em `request_events`

Cada requisicao vira uma linha com campos como:

- `ts`: horario da requisicao;
- `service`: nome do servico;
- `endpoint`: rota chamada;
- `method`: metodo HTTP;
- `version`: `v1` ou `v2`;
- `status_code`: codigo HTTP retornado;
- `latency_ms`: tempo de resposta;
- `level`: `INFO`, `WARN` ou `ERROR`;
- `error_message`: mensagem de erro, quando houver;
- `trace_id`: identificador sintetico da requisicao.

## Como a regressao aparece

Na `v1`, o `/checkout` responde normalmente.

Na `v2`, o `/checkout` tem comportamento ruim:

- demora mais;
- as vezes retorna HTTP 500;
- quando falha, grava a mensagem `database connection pool exhausted`.

Essa mensagem nao significa que ha um banco real esgotando conexoes. E uma simulacao intencional de um problema comum em producao, usada para que a demo tenha uma hipotese tecnica facil de explicar.

## Como o deploy aparece

Depois de 2 minutos, o `loadgen` grava uma linha em `deploy_events`:

```text
Deploy da versao v2 do servico de pedidos
```

O Grafana usa essa tabela para desenhar a anotacao vertical de deploy nos graficos.

## Por que a v1 pode sumir do dashboard

O dashboard normalmente abre em `Last 15 minutes`. Como a `v1` recebe trafego apenas nos primeiros 2 minutos da demo, ela pode sumir se a demo ficar rodando por muito tempo.

Para ver a `v1` novamente:

- aumente a janela para `Last 30 minutes` ou `Last 1 hour`; ou
- rode `make reset` para reiniciar a demo do zero.