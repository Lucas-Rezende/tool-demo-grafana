# Validacao da correcao: rollback

A demo agora tem quatro fases, cada uma com 3 minutos de duracao:

1. `v1`: sistema saudavel.
2. `v2`: deploy com regressao no `/checkout`.
3. `rollback`: retorno para uma versao estavel.

Essa linha do tempo permite demonstrar o sexto ponto do slide: acompanhar se a correcao funcionou.

## O que deve aparecer no Grafana

Durante a `v1`, a taxa de erro 5xx deve ficar proxima de zero e a latencia P95 deve ficar baixa.

Durante a `v2`, a taxa de erro 5xx sobe e a latencia P95 aumenta, principalmente no endpoint `/checkout`.

Durante o `rollback`, a taxa de erro deve cair novamente e a latencia deve voltar ao patamar saudavel.

## Como explicar

Fala sugerida:

> Depois de identificar a regressao na v2, a equipe pode fazer rollback ou publicar uma versao corrigida. O Grafana ajuda a validar se a manutencao funcionou: os mesmos paineis que mostraram a falha agora mostram erro e latencia voltando ao normal.

## Quanto tempo deixar rodando

Para uma demonstracao completa, deixe a demo rodar por cerca de 11 a 12 minutos apos `make reset` ou `make demo`:

- 3 minutos de baseline saudavel;
- 3 minutos de problema na v2;
- 4 minutos de rollback;

Use uma janela de tempo de `Last 15 minutes` ou `Last 30 minutes` no Grafana.