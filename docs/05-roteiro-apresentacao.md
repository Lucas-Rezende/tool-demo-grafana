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

**🔖 Favorito 1** — a cópia do `MLT Dashboard`, janela completa.

Percorrer, nesta ordem:

1. **Taxa de erro por endpoint.** Existe um endpoint com erro claramente acima
   dos outros. Apontar.
2. **Latência.** Mostrar o painel de percentil 95 e o de latência por endpoint.
   Comentar que é isto que responde "o que vale otimizar" — a manutenção
   perfectiva do slide anterior.
3. **Variável de template.** 🔖 **Favorito 2** — o mesmo dashboard com
   `httpEndpoint` fixado no endpoint problemático. Explicar que trocar o
   seletor reescreve todas as consultas da tela de uma vez, e que existe
   também um seletor por `service.version`, que é o que permite comparar
   versões implantadas.

### Fala de transição para a pessoa 2

> Então a métrica já respondeu duas coisas: que existe erro, e em qual
> endpoint. O que ela não diz é **qual** erro. Para isso a gente precisa de
> outro sinal.

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

Ler uma linha de erro em voz alta. Mostrar que a mensagem se repete e que
carrega um `traceId`.

### 7:00 – 8:00 · 🔖 Agregação de log em gráfico

**🔖 Favorito 4** — a mesma consulta transformada em métrica:

```logql
sum by (endpoint) (count_over_time({job="alloy"} | logfmt | status="Error" [1m]))
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

Na cascata de spans:

1. Mostrar a estrutura: a requisição entra em um serviço, que chama outro, que
   chama o banco.
2. Achar **o span com erro** (marcado em vermelho).
3. Abrir os atributos do span e mostrar a dependência culpada e a mensagem.

Dizer o que acabou de acontecer:

> A métrica disse que existe erro. O log disse como ele se manifesta. O trace
> disse onde: neste serviço, neste span, nesta chamada. Saímos de "às vezes dá
> 500" para uma linha específica de um serviço específico. Isso é diagnóstico
> de manutenção corretiva feito sobre um sistema em execução, sem conseguir
> reproduzir o defeito localmente.

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
