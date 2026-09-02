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
   `/unicorn`. Na janela gravada eles ficam entre **4,24% e 4,99%**.
   **Nenhum se destaca.**

3. **Variável de template, usada para descartar uma hipótese.**
   🔖 **Favorito 2** — o mesmo dashboard com `httpEndpoint` fixado em
   `/owlbear`, que é o endpoint do trace que aparece no bloco 2.

   Este é o momento pedagógico do bloco: a primeira hipótese de qualquer
   pessoa é "deve ser um endpoint específico", e a variável de template é o
   que permite testar isso em dois segundos. O resultado é que a hipótese
   **cai**: o erro é transversal.

   Aproveitar para explicar que trocar o seletor reescreve todas as consultas
   da tela de uma vez, e que existe também um seletor por `service.version`,
   que é o que permite comparar versões implantadas.

4. **Latência — o segundo fato.** O painel
   `95th Percentile Response Latencies (ms)` marca cerca de **15 000 ms**, ou
   seja, 15 segundos, em todos os cinco endpoints. O painel
   `Top 10 Highest Endpoint Latencies` marca cerca de **9 s**.

   Ou seja, existem **dois** fatos na tela, não um:

   - cerca de 5% das requisições falham;
   - a aplicação está lenta, na casa dos segundos.

   Aproveitar para dizer que é este tipo de painel que responde "o que vale
   otimizar" — a manutenção perfectiva do slide anterior.

### Fala de transição para a pessoa 2

> A métrica derrubou uma hipótese e deixou dois fatos: cerca de 5% de erro,
> espalhado por todos os endpoints, e uma latência na casa dos segundos.
>
> A pergunta óbvia é se as duas coisas são a mesma coisa — se os 5% que falham
> são justamente os lentos. É a hipótese que qualquer pessoa levanta aqui. E a
> métrica agregada **não consegue responder isso**, porque ela já somou tudo.
> Para responder, precisamos descer um nível.

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

### 6:00 – 7:00 · O padrão do erro

Ler uma linha de erro em voz alta. São autologs gerados pelo Alloy a partir dos
traces, em formato logfmt, e têm esta cara:

```
span=requester dur=11468966702ns status=Error svc=mythical-requester traceId=e331212c4c60d3e6bd2a6a24ff42401c
```

Os campos disponíveis para filtrar são `span`, `dur`, `status`, `svc` e
`traceId`.

Repare no `dur` da linha de erro: **11 segundos**. É tentador parar aqui e
concluir que o erro é a causa da lentidão. Não pare.

### 7:00 – 8:00 · 🔖 O gráfico que derruba a segunda hipótese

**🔖 Favorito 4** — a mesma fonte de dados, outra pergunta:

```logql
quantile_over_time(0.5,
  {job="alloy"} | logfmt | svc="mythical-requester" | status=~"Ok|Error"
  | unwrap duration(dur) [5m]
) by (status)
```

Duas coisas a explicar, nesta ordem.

Primeiro, **o que a consulta faz**: ela extrai o campo `dur` de cada linha,
converte para número e calcula a mediana em janelas de 5 minutos, separando
por status. Log virou série temporal. Isso costuma surpreender quem só conhece
log como texto rolando na tela — e é o que permite comparar duas populações.

Segundo, **o resultado**. O gráfico tem duas linhas, `status="Ok"` e
`status="Error"`, e elas **se sobrepõem** ao longo dos 45 minutos inteiros.
Na janela gravada, as medianas ficam em torno de 8 a 11 segundos para as duas.

> A hipótese cai. As requisições que falham **não** são as lentas. Falhar e
> demorar são dois problemas independentes deste sistema, e a gente só
> descobriu isso porque conseguiu comparar as duas populações lado a lado.
>
> Isso importa para manutenção: se a gente tivesse "corrigido o erro"
> esperando que a latência melhorasse, teria gasto uma sprint para descobrir
> que não melhorou nada.

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

O trace escolhido tem **18 spans** em 2 serviços e dura **13,73 s**. Percorrer
a cascata seguindo o tempo, não a estrutura:

1. **`requester` (mythical-requester), 13,72 s, vermelho.** A requisição
   inteira.
2. **`POST /:endpoint` (mythical-server), 9,44 s, vermelho.** O servidor
   consumiu a maior parte.
3. **Os middlewares: 567 µs, 280 µs, 245 µs, 57 µs.** Microssegundos. Mostrar
   isso é importante — é a prova de que o código da aplicação **não** é o
   gargalo.
4. **`pg.query:INSERT postgres` (mythical-server), 9,44 s, vermelho.** Os
   9,44 segundos inteiros do servidor estão dentro de **uma única chamada ao
   banco**. Esta é a dependência culpada.

Clicar nesse span. O painel de detalhe entrega o diagnóstico inteiro:

```
pg.query:INSERT postgres
Service: mythical-server   Duration: 9.44s   Kind: client   Status: error
Status Message: null value in column "name" of relation "owlbear"
                violates not-null constraint
db.query.text:  INSERT INTO owlbear(name) VALUES ($1)
db.namespace:   postgres
evento exception: PostgreSQL error of type 'error' occurred (code: 23502)
```

Ou seja: **a aplicação aceita um `name` nulo, manda para o banco, e quem
rejeita é a constraint `NOT NULL`.** A validação que deveria estar na borda da
aplicação só existe no schema do banco.

E o trace fecha também o outro fato, o da lentidão: o tempo não está no código
da aplicação, está esperando o banco. Vale dizer que o mesmo span leva segundos
**mesmo quando a requisição dá certo** — é o que explica as duas linhas
sobrepostas do favorito 4.

Dizer o que acabou de acontecer:

> A métrica disse que existe erro e derrubou a hipótese do endpoint. O log
> derrubou a hipótese de que erro e lentidão eram a mesma coisa. O trace
> respondeu as duas perguntas de uma vez: o erro é sempre este `INSERT`, com
> esta mensagem do Postgres; e a lentidão é a espera pelo banco, não o código
> da aplicação.
>
> Saímos de "às vezes dá 500 e o sistema está lento" para dois problemas
> nomeados: falta validar `name` antes de chamar o banco, e a chamada ao banco
> está demorando segundos.
>
> Repare no tipo do primeiro defeito: é um defeito que revisão de código não
> pega com facilidade, porque a regra violada não mora no código, mora no
> schema do banco.

### 10:00 – 10:30 · Fala de transição para a pessoa 3

> E tudo isso foi reativo: alguém precisou estar olhando a tela. A última peça
> do Grafana é a que fecha esse ciclo.

---

## Bloco 3 — Pessoa 3 (10:30 – 15:00)

### 10:30 – 12:00 · 🔖 Regras de alerta

**🔖 Favorito 6** — a lista de regras, já em modo lista, mostrando as duas.

1. Abrir a regra **realista** (`Taxa de erro acima de 5%`). Mostrar as três
   partes: consulta, condição e roteamento da notificação. Dizer que ela foi
   escrita sobre a mesma métrica do painel — é a mesma consulta, com uma
   condição em cima.

2. Explicar a diferença de semântica de tempo, que é o ponto conceitual do
   bloco:

   > Um dashboard consulta o intervalo que você pedir, inclusive no passado.
   > Uma regra de alerta não: o motor roda a consulta **agora**, a cada 10
   > segundos. Então esta regra aqui **não** está olhando a janela gravada que
   > vocês viram no dashboard. Ela está olhando o tráfego que esta aplicação
   > começou a gerar quando a gente subiu o stack, uns quinze minutos atrás.
   >
   > São duas semânticas de tempo diferentes dentro da mesma ferramenta, e
   > confundir as duas é um erro comum quando se começa a escrever alerta.

   Ler o estado que estiver na tela — normalmente `Normal`, às vezes `Pending`
   ou `Alerting` se o tráfego novo passar de 5%. **Não prometa um estado
   específico antes de olhar.** Logo depois de um `restore`, antes de a janela
   de 5 minutos encher, ela fica em `Pending (NoData)`, que é o que apareceria
   se o dado tivesse mesmo parado.

3. **🔖 Favorito 7** — a regra **sintética**, nomeada
   `[SINTÉTICA] Demonstração de transição de estado`. Dizer que ela usa
   `vector(1) > 0`, que não depende de dado nenhum, e que existe só para tornar
   visível o ciclo de estados. Mostrar `Normal → Pending → Alerting`: com
   avaliação a cada 10 s e pendência de 30 s, o ciclo fecha em menos de um
   minuto.

   Dizer em voz alta que ela é sintética. Custa cinco segundos e é a diferença
   entre uma demo bem-feita e uma demo que engana.

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
