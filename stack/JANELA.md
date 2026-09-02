# Janela gravada e URLs congeladas

Preencha este arquivo depois de rodar `make record` e `make freeze`.
Ele é a folha de cola do dia da apresentação: com os dois epochs e os links
abaixo, ninguém precisa mexer no seletor de tempo do Grafana ao vivo.

## 1. Epochs da janela

| Campo | Valor (epoch em milissegundos) | Legível |
|---|---|---|
| Início (`from`) | `PREENCHER` | `PREENCHER` |
| Fim (`to`)      | `PREENCHER` | `PREENCHER` |

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
| 1 | Abertura | Pessoa 1 | `MLT Demo`, janela completa. Erro geral ~5% | `PREENCHER` |
| 2 | Abertura | Pessoa 1 | Mesmo dashboard com `var-httpEndpoint=/beholder`, para **derrubar** a hipótese de que o erro é de um endpoint só | `PREENCHER` |
| 3 | Logs | Pessoa 2 | Explore + Loki, `{job="alloy"} \| logfmt \| status="Error"` | `PREENCHER` |
| 4 | Logs | Pessoa 2 | Mesma query agregada: `sum by (svc) (count_over_time({job="alloy"} \| logfmt \| status="Error" [1m]))` | `PREENCHER` |
| 5 | Traces | Pessoa 2 | Trace específico no Tempo — a cascata até o span do Postgres | `PREENCHER` |
| 6 | Alertas | Pessoa 3 | Lista de regras de alerta | `PREENCHER` |
| 7 | Alertas | Pessoa 3 | Regra sintética, para mostrar a transição de estado | `PREENCHER` |

> Ao abrir o favorito 1, **role a tela uma vez**. O Grafana só renderiza o
> painel quando ele entra na área visível.

### O trace do favorito 5

Precisa ser um trace **de dentro da janela**, com span em erro. Escolha durante
o ensaio e anote:

- Trace ID: `PREENCHER`
- Endpoint: `PREENCHER` (ex.: `/beholder`)
- Duração total: `PREENCHER` (~20 s nos casos com erro)
- Span culpado: `pg.query:INSERT postgres`, no serviço `mythical-server`
- SQL no span: `INSERT INTO <endpoint>(name) VALUES ($1)`
- Mensagem: `null value in column "name" ... violates not-null constraint`
  (SQLSTATE 23502)

### Números para citar de cor

Medidos sobre a janela gravada. Confira e atualize se regravarem.

| Medida | Valor |
|---|---|
| Erro geral | `PREENCHER` % |
| Erro por endpoint | entre `PREENCHER` % e `PREENCHER` % — sem destaque |
| Duração mediana, `status="Ok"` | `PREENCHER` ms |
| Duração mediana, `status="Error"` | `PREENCHER` ms |

## 4. Conferência final (marcar antes de apresentar)

- [ ] `make restore` rodou sem erro
- [ ] `make verify` deu tudo verde
- [ ] Os 7 favoritos abrem com dados, sem tocar no seletor de tempo
- [ ] O container `k6` não está no ar
- [ ] Nenhum favorito aponta para Pyroscope ou para o dashboard do k6
- [ ] Vídeo de backup gravado (ver `docs/07-plano-de-contingencia.md`)
