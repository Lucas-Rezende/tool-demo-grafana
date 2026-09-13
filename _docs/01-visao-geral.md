# Visao geral da demo

Esta demo mostra o Grafana como ferramenta de apoio a manutenção corretiva de software.

A historia simulada é simples: uma API de pedidos funcionava normalmente na versao `v1`. Depois de um deploy para `v2`, o endpoint `/checkout` passou a ficar lento e a falhar algumas vezes. O Grafana é usado para investigar esse comportamento.

## Componentes

```text
loadgen
  |
  | envia requisições HTTP
  v
orders-api-v1        orders-api-v2
sem bug              com regressão no /checkout
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

## Papel de cada componente

- `orders-api-v1`: versão sausável saudavel da API.
- `orders-api-v2`: mesma API, mas com regressao proposital no `/checkout`.
- `loadgen`: simula usuarios chamando endpoints da API.
- `postgres`: armazena os eventos de requisicao e o marcador de deploy.
- `grafana`: consulta o PostgreSQL e apresenta os dados em dashboards.

## O que a demo prova

A demo nao mostra que o Grafana corrige bugs sozinho. Ela mostra que o Grafana ajuda a equipe a sair de uma reclamacao vaga para uma investigacao baseada em evidencias:

1. algo mudou no comportamento do sistema;
2. a mudanca coincide com um deploy;
3. o problema se concentra em uma versao e em um endpoint;
4. os registros de erro sugerem uma hipotese tecnica;
5. apos uma correcao ou rollback, os mesmos paineis ajudariam a validar a melhora.