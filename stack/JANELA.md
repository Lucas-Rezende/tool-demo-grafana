# Janela gravada e URLs congeladas

Folha de cola do dia da apresentação: com os dois epochs e os links abaixo,
ninguém precisa mexer no seletor de tempo do Grafana ao vivo.

**Já está preenchido** com a janela que acompanha o `snapshot/` distribuído
para o grupo. Se vocês regravarem (`make record-zero` e `make freeze`), rode
`make urls` e substitua os valores desta página.

## 1. Epochs da janela

| Campo | Valor (epoch em milissegundos) | Legível |
|---|---|---|
| Início (`from`) | `1788350392295` | `02/09/2026 08:59:52` |
| Fim (`to`)      | `1788353142417` | `02/09/2026 09:45:42` |

Os dois números saem de `snapshot/janela.env` (gerado automaticamente) e são
repetidos em `snapshot/congelado-em.txt`.

Confira a janela antes de apresentar:

```bash
make verify
```

## 2. Como montar uma URL congelada

Abra a visualização no Grafana com o intervalo desejado, copie a URL e troque
o trecho de tempo por valores absolutos:

```
http://localhost:3000/d/<uid>/<slug>?orgId=1&from=<INICIO_MS>&to=<FIM_MS>
```

UIDs dos dashboards provisionados no commit fixado (a cópia da demo terá um
UID próprio, gerado na hora de salvar):

| Dashboard | UID |
|---|---|
| MLT Dashboard | `ed4f4709-4d3b-48fd-a311-a036b85dbd5b` |
| MLT Erroring Endpoints | `9UKWKDqVy` |
| Traces in Dashboards | `b550438e-5e9a-4bfa-8d1d-68a0104c09f2` |
| ~~Official k6 Test Result~~ | fora do escopo, não abrir |

Regras que valem para todos os links:

- `from` e `to` **sempre** em epoch ms. Nunca `from=now-1h`: com dados
  congelados, `now` está fora da janela e o painel aparece vazio.
- Inclua `&var-<nome>=<valor>` para fixar as variáveis de template que a demo
  usa (`httpEndpoint`, `httpStatus`, `serviceVersion` no MLT Dashboard).
- Salve cada link como favorito do navegador, **numerado na ordem do
  roteiro**. No dia, a demo vira uma sequência de cliques na barra de
  favoritos.

## 3. Favoritos, na ordem do roteiro

Gere tudo de uma vez, com o stack no ar:

```bash
ENDPOINT=/beholder TRACE=<trace-id> make urls
```

O script imprime as sete URLs e grava `snapshot/favoritos.html`, importável no
navegador (Favoritos → Gerenciar → Importar de arquivo HTML). Cole as URLs
aqui também, para o caso de alguém precisar montar à mão.

| # | Bloco | Quem | O que mostra | URL congelada |
|---|---|---|---|---|
| 1 | Abertura | Pessoa 1 | `MLT Demo`, janela completa. Erro geral ~5% | <http://localhost:3000/d/mlt-demo/mlt-demo-tool-demo-dcc-ufmg?orgId=1&from=1788350392295&to=1788353142417> |
| 2 | Abertura | Pessoa 1 | Mesmo dashboard com `var-httpEndpoint=/beholder`, para **derrubar** a hipótese de que o erro é de um endpoint só | <http://localhost:3000/d/mlt-demo/mlt-demo-tool-demo-dcc-ufmg?orgId=1&from=1788350392295&to=1788353142417&var-httpEndpoint=%2Fowlbear&var-httpStatus=%24__all&var-serviceVersion=%24__all> |
| 3 | Logs | Pessoa 2 | Explore + Loki, `{job="alloy"} \| logfmt \| status="Error"` | <http://localhost:3000/explore?orgId=1&schemaVersion=1&panes=%7B%22demo%22%3A%7B%22datasource%22%3A%22loki%22%2C%22queries%22%3A%5B%7B%22refId%22%3A%22A%22%2C%22datasource%22%3A%7B%22type%22%3A%22loki%22%2C%22uid%22%3A%22loki%22%7D%2C%22editorMode%22%3A%22code%22%2C%22expr%22%3A%22%7Bjob%3D%5C%22alloy%5C%22%7D%20%7C%20logfmt%20%7C%20status%3D%5C%22Error%5C%22%22%2C%22queryType%22%3A%22range%22%7D%5D%2C%22range%22%3A%7B%22from%22%3A%221788350392295%22%2C%22to%22%3A%221788353142417%22%7D%7D%7D> |
| 4 | Logs | Pessoa 2 | Mesma query agregada: `sum by (svc) (count_over_time({job="alloy"} \| logfmt \| status="Error" [1m]))` | <http://localhost:3000/explore?orgId=1&schemaVersion=1&panes=%7B%22demo%22%3A%7B%22datasource%22%3A%22loki%22%2C%22queries%22%3A%5B%7B%22refId%22%3A%22A%22%2C%22datasource%22%3A%7B%22type%22%3A%22loki%22%2C%22uid%22%3A%22loki%22%7D%2C%22editorMode%22%3A%22code%22%2C%22expr%22%3A%22quantile_over_time%280.5%2C%20%7Bjob%3D%5C%22alloy%5C%22%7D%20%7C%20logfmt%20%7C%20svc%3D%5C%22mythical-requester%5C%22%20%7C%20status%3D~%5C%22Ok%7CError%5C%22%20%7C%20unwrap%20duration%28dur%29%20%5B5m%5D%29%20by%20%28status%29%22%2C%22queryType%22%3A%22range%22%7D%5D%2C%22range%22%3A%7B%22from%22%3A%221788350392295%22%2C%22to%22%3A%221788353142417%22%7D%7D%7D> |
| 5 | Traces | Pessoa 2 | Trace específico no Tempo — a cascata até o span do Postgres | <http://localhost:3000/explore?orgId=1&schemaVersion=1&panes=%7B%22demo%22%3A%7B%22datasource%22%3A%22tempo%22%2C%22queries%22%3A%5B%7B%22refId%22%3A%22A%22%2C%22datasource%22%3A%7B%22type%22%3A%22tempo%22%2C%22uid%22%3A%22tempo%22%7D%2C%22queryType%22%3A%22traceql%22%2C%22query%22%3A%223b2218492d592f7ceaf20bf83f18fbf%22%7D%5D%2C%22range%22%3A%7B%22from%22%3A%221788350392295%22%2C%22to%22%3A%221788353142417%22%7D%7D%7D> |
| 6 | Alertas | Pessoa 3 | Lista de regras de alerta | <http://localhost:3000/alerting/list?orgId=1&view=list> |
| 7 | Alertas | Pessoa 3 | Regra sintética, para mostrar a transição de estado | <http://localhost:3000/alerting/grafana/efx1e3y5z0nwgc/view?orgId=1> |

> Ao abrir o favorito 1, **role a tela uma vez**. O Grafana só renderiza o
> painel quando ele entra na área visível.

### O trace do favorito 5

Precisa ser um trace **de dentro da janela**, com span em erro. O escolhido
para o snapshot atual:

- Trace ID: `3b2218492d592f7ceaf20bf83f18fbf`
- Endpoint: `/owlbear`
- Duração total: **13,73 s**, 18 spans, 2 serviços
- Span do servidor: `POST /:endpoint`, **9,44 s**
- Middlewares da aplicação: 567 µs, 280 µs, 245 µs, 57 µs — irrelevantes
- Span culpado: `pg.query:INSERT postgres`, no serviço `mythical-server`, **9,44 s** — praticamente todo o tempo do servidor
- SQL no span: `INSERT INTO owlbear(name) VALUES ($1)`
- Mensagem: `null value in column "name" of relation "owlbear" violates
  not-null constraint` (SQLSTATE 23502)

### Números para citar de cor

Medidos sobre a janela gravada. Confira e atualize se regravarem.

| Medida | Valor |
|---|---|
| Linhas de log na janela | 42 898 `Ok` + 2 412 `Error` |
| Taxa de erro | **5,3%** (o painel `Overall Error %age` marca ~5%) |
| Erro por endpoint, média de 30 min | `/manticore` 4,99% · `/owlbear` 4,91% · `/unicorn` 4,78% · `/beholder` 4,68% · `/illithid` 4,24% |
| Erro por endpoint, no painel (janela de 5 min) | oscila entre ~4% e ~6%; **qual está no topo muda** conforme o instante |
| `95th Percentile Response Latencies` | ~15 000 ms (15 s) |
| Duração mediana, `status="Ok"` | ~8,8 s |
| Duração mediana, `status="Error"` | ~8,3 s |
| Conclusão | as duas medianas são **iguais**: erro e lentidão são problemas independentes |
| Média do span `pg.query:INSERT postgres` | 7,3 s com erro · 7,0 s sem erro |

## 4. Conferência final (marcar antes de apresentar)

- [ ] `make restore` rodou sem erro
- [ ] `make verify` deu tudo verde
- [ ] Os 7 favoritos abrem com dados, sem tocar no seletor de tempo
- [ ] O container `k6` não está no ar
- [ ] Nenhum favorito aponta para Pyroscope ou para o dashboard do k6
- [ ] `snapshot/demo-backup.mp4` abre no player da máquina que apresenta
- [ ] `snapshot/favoritos.html` importado no navegador da máquina que apresenta
