# 05 — Roteiro da apresentação

15 minutos, 3 pessoas, blocos contíguos. Blocos contíguos são uma decisão
deliberada: cada troca de bastão custa uns 15 segundos de atrapalhação, e três
trocas são muito melhores que nove.

O roteiro sugerido pelo professor é 2 minutos de visão geral, 10 minutos de
features e prova de conceito, 3 minutos de conclusão. A divisão abaixo respeita
essa proporção.

| Bloco | Tempo | Quem | Conteúdo |
|---|---|---|---|
| 1 | 0:00–5:00 | Pessoa 1 | Visão geral, data sources, cenário, dashboard |
| 2 | 5:00–10:30 | Pessoa 2 | Logs e traces — o clímax |
| 3 | 10:30–15:00 | Pessoa 3 | Alertas, amarração, pontos fortes e fracos |

Cada passo marcado com 🔖 é um favorito do navegador já preparado. Ver
[`stack/JANELA.md`](../stack/JANELA.md).

---

## Bloco 1 — Pessoa 1 (0:00 – 5:00)

### 0:00 – 1:00 · Slide: o que é o Grafana

Abrir com a definição, sem rodeios:

> O Grafana é uma camada de visualização, consulta e alerta sobre dados que ele
> não coleta nem armazena.

Mostrar o diagrama das três caixas (`01-visao-geral-grafana.md`). Enfatizar a
seta que aponta para cima: o Grafana **puxa** o dado da fonte, no momento da
consulta. Não há agente do Grafana na aplicação, não há banco do Grafana.

Encaixar aqui a distinção arquitetural, em uma ou duas frases, e seguir:

> Isso é diferente de uma ferramenta como o Sentry, que é centrada em exceção:
> lá um SDK dentro da aplicação captura o erro e o liga à release e ao commit.
> O Grafana é agnóstico ao tipo de sinal — ele consulta o que já existe.

### 1:00 – 2:00 · Slide: as três peças e o lugar na manutenção

Data sources, dashboards e painéis, alerting. Uma frase por peça.

Fechar com a ligação com a disciplina, que é o eixo do trabalho:

> Observabilidade é o ciclo de feedback da evolução do software. Sem ela, toda
> mudança é feita no escuro.

Citar os três tipos: corretiva (diagnosticar o que não reproduz localmente),
perfectiva (medir antes de mexer), evolução (comparar versões).

### 2:00 – 2:30 · O cenário

Descrever a aplicação de exemplo em 30 segundos: três microsserviços
instrumentados com OpenTelemetry, uma fila, um Postgres. Métricas no Mimir,
logs no Loki, traces no Tempo.

Dizer que os dados na tela são de uma janela real gravada previamente, e que o
intervalo é absoluto. É honesto, é rápido e evita a pergunta.

### 2:30 – 5:00 · 🔖 Demo parte 1: o dashboard

**🔖 Favorito 1** — `MLT Demo`, janela completa.

> Ao abrir, **role a tela uma vez**. O Grafana só renderiza o painel quando ele
> entra na área visível; num dashboard recém-carregado a área de baixo aparece
> vazia por um instante.

Percorrer, nesta ordem:

1. **Taxa de erro.** O painel `Overall Error %age` marca cerca de **5%**.
   Existe defeito, e ele não é raro.

2. **Erro por endpoint.** O painel `Error Percentages by Target` mostra os
   cinco endpoints — `/beholder`, `/illithid`, `/manticore`, `/owlbear`,
   `/unicorn` — todos entre 4% e 5,5%. **Nenhum se destaca.**

3. **Variável de template, usada para descartar uma hipótese.**
   🔖 **Favorito 2** — o mesmo dashboard com `httpEndpoint` fixado em
   `/beholder`. Este é o momento pedagógico do bloco: a primeira hipótese de
   qualquer pessoa é "deve ser um endpoint específico", e a variável de
   template é o que permite testar isso em dois segundos. O resultado é que a
   hipótese **cai**: o erro é transversal.

   Aproveitar para explicar que trocar o seletor reescreve todas as consultas
   da tela de uma vez, e que existe também um seletor por `service.version`,
   que é o que permite comparar versões implantadas.

4. **Latência — e a pista que sobra.** O painel
   `95th Percentile Response Latencies (ms)` marca cerca de **15 000 ms**, ou
   seja, 15 segundos, em todos os cinco endpoints. Deixar essa pista no ar sem
   resolver:

   > Repare: o percentil 95 está em 15 segundos. Se 95% das requisições
   > estivessem lentas assim, a aplicação estaria inutilizável — e ela não
   > está. Então alguma coisa aqui é muito lenta e é minoria. Guardem isso.

   Aproveitar para dizer que é este tipo de painel que responde "o que vale
   otimizar" — a manutenção perfectiva do slide anterior — e que percentil
   existe justamente porque média esconde cauda.

### Fala de transição para a pessoa 2

> A métrica respondeu uma coisa, derrubou uma hipótese e deixou uma pista.
> Existe erro, cerca de 5%; ele **não** está concentrado num endpoint; e o
> percentil 95 está em 15 segundos. O que a métrica não diz é qual é o erro,
> nem se essas duas coisas têm relação. Para isso a gente precisa de outro
> sinal.

---

## Bloco 2 — Pessoa 2 (5:00 – 10:30)

Este é o clímax. É o bloco que prova que o grupo entendeu e conseguiu rodar a
ferramenta.

### 5:00 – 6:00 · 🔖 Logs no Explore

**🔖 Favorito 3** — Explore com a fonte Loki e a consulta:

```logql
{job="alloy"} | logfmt | status="Error"
```

Explicar em uma frase o modelo do Loki: ele indexa **rótulos**, não o conteúdo
da linha. Por isso a consulta começa por um seletor de fluxo entre chaves e só
depois filtra.

### 6:00 – 7:00 · O padrão do erro — e a descoberta do bloco

Ler uma linha de erro em voz alta. São autologs gerados pelo Alloy a partir dos
traces, em formato logfmt, e têm esta cara:

```
span=requester dur=11468966702ns status=Error svc=mythical-requester traceId=e331212c4c60d3e6bd2a6a24ff42401c
```

Os campos disponíveis para filtrar são `span`, `dur`, `status`, `svc` e
`traceId`.

**Aqui está a descoberta que a métrica não deu.** Olhe o `dur`: são
**11 segundos**. Troque o filtro para `status="Ok"` e leia uma linha normal: o
`dur` fica na casa das **dezenas de milissegundos**.

Na janela gravada, a diferença é esta:

| | mediana | p95 |
|---|---|---|
| `status="Ok"` | ~30 ms | ~93 ms |
| `status="Error"` | ~11 s | ~23 s |

Dizer em voz alta o que isso significa, e fechar a pista deixada no bloco 1:

> Não é só um erro. É um erro **lento**. A requisição que falha custa umas
> trezentas vezes mais que a que dá certo. E é isto que estava puxando o
> percentil 95 para 15 segundos lá no dashboard: não é a aplicação inteira
> que está lenta, são os 5% que falham. As duas coisas que pareciam separadas
> são o mesmo defeito.

### 7:00 – 8:00 · 🔖 Agregação de log em gráfico

**🔖 Favorito 4** — a mesma consulta transformada em métrica:

```logql
sum by (svc) (count_over_time({job="alloy"} | logfmt | status="Error" [1m]))
```

O ponto a fazer: **log vira série temporal**. É o mesmo dado, com outra
pergunta. Isso costuma surpreender quem só conhece log como texto rolando na
tela.

### 8:00 – 10:00 · 🔖 O salto para o trace

Este é o momento mais importante da apresentação inteira. Não corra.

Voltar ao painel de logs, clicar no `traceId` da linha de erro. O Grafana abre
o Tempo ao lado, na mesma tela.

O link existe porque a fonte de dados Loki está configurada com um *derived
field*: uma expressão regular que reconhece `traceId=` na linha de log e o
transforma em link para a fonte Tempo. Vale dizer isso — é a correlação entre
sinais sendo configurada, não mágica.

**🔖 Favorito 5** — o trace escolhido no ensaio, aberto direto, como plano B
caso o clique não funcione.

Na cascata de spans, seguir o tempo, não a estrutura:

1. **`requester` (mythical-requester), ~22 s, vermelho.** A requisição inteira.
2. **`POST /:endpoint` (mythical-server), ~14 s, vermelho.** O servidor
   consumiu a maior parte. Já dá para dizer: o problema não está no cliente.
3. **`pg.query:INSERT postgres` (mythical-server), ~13,7 s, vermelho.**
   Praticamente todo o tempo do servidor está dentro de **uma única chamada ao
   banco**. Esta é a dependência culpada.

Abrir os atributos desse span. Eles entregam o diagnóstico inteiro:

```
db.system.name  = postgresql
db.query.text   = INSERT INTO beholder(name) VALUES ($1)
server.address  = mythical-database
status.message  = null value in column "name" of relation "beholder"
                  violates not-null constraint
evento exception: PostgreSQL error of type 'error' occurred (code: 23502)
```

Ou seja: **a aplicação aceita um `name` nulo, manda para o banco, e quem
rejeita é a constraint `NOT NULL`.** A validação que deveria estar na borda da
aplicação só existe no schema do banco — e essa checagem custa 13 segundos por
requisição.

Dizer o que acabou de acontecer:

> A métrica disse que existe erro e derrubou a hipótese do endpoint. O log
> disse que o erro é lento. O trace disse exatamente onde: neste serviço, neste
> span, neste `INSERT`, com este SQL e esta mensagem do Postgres. Saímos de
> "às vezes dá 500" para "falta validar `name` antes de chamar o banco".
>
> Isso é diagnóstico de manutenção corretiva feito sobre um sistema em
> execução. E repare no tipo de defeito: é um defeito que revisão de código não
> pega com facilidade, porque a regra que está sendo violada não mora no
> código, mora no schema do banco.

### 10:00 – 10:30 · Fala de transição para a pessoa 3

> E tudo isso foi reativo: alguém precisou estar olhando a tela. A última peça
> do Grafana é a que fecha esse ciclo.

---

## Bloco 3 — Pessoa 3 (10:30 – 15:00)

### 10:30 – 12:00 · 🔖 Regras de alerta

**🔖 Favorito 6** — a lista de regras de alerta.

1. Abrir a regra **realista** (`Taxa de erro acima de 5%`). Mostrar as três
   partes: consulta, condição, roteamento da notificação. Explicar que ela foi
   escrita sobre a mesma métrica do painel — é a mesma consulta, com uma
   condição em cima.

2. Explicar, sem rodeios, a limitação da demo:

   > Os dados desta demonstração são de uma janela gravada. Uma regra de alerta
   > avalia a consulta agora, então esta regra aqui não encontra dado no
   > presente e fica em `No Data` em vez de disparar. É uma limitação do nosso
   > dataset congelado, não da ferramenta.

3. **🔖 Favorito 7** — a regra **sintética**, nomeada
   `[SINTÉTICA] Demonstração de transição de estado`. Dizer que ela usa
   `vector(1) > 0`, que não depende de dado nenhum, e que existe só para tornar
   visível o ciclo de estados. Mostrar ao vivo `Normal → Pending → Alerting`.

4. Comentar em uma frase o roteamento e o silenciamento: para onde a
   notificação vai, e como silenciar durante uma janela de manutenção
   planejada.

### 12:00 – 12:30 · Fala de amarração

Esta fala é obrigatória e foi ensaiada. Ela entrega o passo seguinte ao grupo
de Profilers, de forma explícita e cordial:

> A nossa investigação chegou até o span: sabemos o serviço, o endpoint e a
> chamada que falha. A pergunta seguinte é qual função dentro daquele span
> consome o tempo — e essa já é uma pergunta de profiling, que é exatamente o
> que o pessoal do grupo de profilers vai mostrar. É assim que essas
> ferramentas se encaixam: o Grafana estreita o problema de "o sistema está
> ruim" para "este span, neste serviço", e o profiler entra a partir daí.
>
> Saber onde uma ferramenta para e outra começa é parte do trabalho.

### 12:30 – 14:00 · Slides de pontos fortes e fracos

Conteúdo completo em [`06-pontos-fortes-e-fracos.md`](06-pontos-fortes-e-fracos.md).

Quatro fortes, quatro fracos, uma linha cada no slide. Falar os fracos com a
mesma convicção dos fortes — é a parte que mais pesa na nota.

### 14:00 – 15:00 · Fechamento e perguntas

Repetir a frase-síntese e abrir para perguntas.

---

## Divisão de perguntas (combinada antes)

Combinar isso antes evita as duas falhas clássicas: três pessoas falando ao
mesmo tempo, ou ninguém falando.

| Pessoa | Responde sobre |
|---|---|
| 1 | Arquitetura, data sources, modelo de consulta, posicionamento frente a outras ferramentas |
| 2 | Loki e LogQL, Tempo e TraceQL, instrumentação, OpenTelemetry, correlação entre sinais |
| 3 | Alertas e ciclo de estados, operação, custo, limitações, quando **não** usar |

Se a pergunta cair fora de tudo isso, a pessoa 1 assume.

Se a pergunta for sobre profiling ou sobre o Pyroscope: responder que está fora
do nosso escopo por ser o tema do grupo de profilers, e voltar para o
encadeamento entre ferramentas. Não improvisar demonstração.

## Ensaio

- Cronometrar cada bloco separadamente. O bloco 2 é o que mais estoura.
- Rodar `make restore` e `make verify` antes de cada ensaio, para acostumar.
- Ensaiar as três trocas de bastão com as falas de transição escritas acima.
- Ter o vídeo de backup gravado (ver [`07-plano-de-contingencia.md`](07-plano-de-contingencia.md)).
