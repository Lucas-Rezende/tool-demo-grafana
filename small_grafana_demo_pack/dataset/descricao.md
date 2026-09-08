# Dataset da apresentacao

A tabela principal da demo e `request_events`.

Na versao atual da demo, os dados principais nao nascem prontos no banco: eles sao gravados pela API `orders-api` enquanto o container `loadgen` simula usuarios.

Campos:

- `ts`: timestamp da requisicao.
- `service`: nome do servico observado.
- `endpoint`: rota acessada (`/checkout`, `/catalog`, `/login`, `/profile`).
- `method`: metodo HTTP.
- `version`: versao da aplicacao (`v1` ou `v2`).
- `status_code`: codigo HTTP.
- `latency_ms`: latencia medida pela API.
- `level`: nivel do evento (`INFO`, `WARN`, `ERROR`).
- `error_message`: mensagem quando houver falha.
- `trace_id`: identificador sintetico para simular correlacao de requisicao.

Historia embutida:

- Inicio da demo: o loadgen manda trafego para `orders-api-v1`.
- Depois de 2 minutos: o loadgen registra um deploy em `deploy_events`.
- Apos o deploy: o loadgen passa a mandar trafego para `orders-api-v2`.
- Na `v2`, o endpoint `/checkout` apresenta maior latencia e erro 5xx.
- A mensagem principal de erro e `database connection pool exhausted`.

O arquivo `request_events_sample.csv` e apenas uma amostra ilustrativa para plano B ou explicacao offline.
