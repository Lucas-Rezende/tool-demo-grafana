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

Regras que valem para todos os links:

- `from` e `to` **sempre** em epoch ms. Nunca `from=now-1h`: com dados
  congelados, `now` está fora da janela e o painel aparece vazio.
- Inclua `&var-<nome>=<valor>` para fixar as variáveis de template que a demo
  usa (`httpEndpoint`, `httpStatus`, `serviceVersion` no MLT Dashboard).
- Salve cada link como favorito do navegador, **numerado na ordem do
  roteiro**. No dia, a demo vira uma sequência de cliques na barra de
  favoritos.

## 3. Favoritos, na ordem do roteiro

| # | Bloco | Quem | O que mostra | URL congelada |
|---|---|---|---|---|
| 1 | Abertura | Pessoa 1 | Cópia do MLT Dashboard, visão geral | `PREENCHER` |
| 2 | Abertura | Pessoa 1 | Mesmo dashboard com `var-httpEndpoint` filtrado no endpoint problemático | `PREENCHER` |
| 3 | Logs | Pessoa 2 | Explore + Loki, `{job="alloy"} \| logfmt \| status="Error"` | `PREENCHER` |
| 4 | Logs | Pessoa 2 | Mesma query agregada em gráfico (`sum by (...) (count_over_time(...))`) | `PREENCHER` |
| 5 | Traces | Pessoa 2 | Trace específico aberto no Tempo (cascata de spans) | `PREENCHER` |
| 6 | Alertas | Pessoa 3 | Lista de regras de alerta | `PREENCHER` |
| 7 | Alertas | Pessoa 3 | Regra sintética em transição de estado | `PREENCHER` |

> O trace ID do favorito 5 precisa ser um trace **de dentro da janela** e que
> tenha span com erro. Escolha durante o ensaio e anote aqui:
>
> - Trace ID escolhido: `PREENCHER`
> - Endpoint: `PREENCHER`
> - Span culpado: `PREENCHER`

## 4. Conferência final (marcar antes de apresentar)

- [ ] `make restore` rodou sem erro
- [ ] `make verify` deu tudo verde
- [ ] Os 7 favoritos abrem com dados, sem tocar no seletor de tempo
- [ ] O container `k6` não está no ar
- [ ] Nenhum favorito aponta para Pyroscope ou para o dashboard do k6
- [ ] Vídeo de backup gravado (ver `docs/07-plano-de-contingencia.md`)
