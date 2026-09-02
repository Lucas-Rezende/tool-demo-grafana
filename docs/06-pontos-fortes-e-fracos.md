# 06 — Pontos fortes e fracos

Conteúdo dos slides de conclusão, bloco 3 do roteiro. Quatro de cada lado, uma
linha cada no slide, o resto é fala.

A parte de pontos fracos é a que mais pesa na nota. Ela está escrita sem
amenizar, de propósito.

## Pontos fortes

### 1. Sem aprisionamento a fornecedor

O Grafana consulta o backend que a equipe já tem. Se o time usa Prometheus,
Elasticsearch, CloudWatch ou um Postgres com uma tabela de eventos, o Grafana
lê de lá. Trocar de backend depois não obriga a jogar fora os dashboards, e
adotar o Grafana não obriga a migrar dado nenhum.

Isso é uma consequência direta da decisão de arquitetura de 2014 de não trazer
banco de dados junto.

### 2. Sinais correlacionados na mesma interface

Métrica, log e trace na mesma tela, com navegação de um para o outro. A demo
mostra isso literalmente: do gráfico de erro para a linha de log, da linha de
log para o trace, do trace para o span.

Sem isso, a investigação vira alternância entre três ferramentas com três
seletores de tempo diferentes, e a maior parte do esforço é remontar o contexto
a cada troca.

### 3. Exploração ad hoc, sem construir dashboard antes

O Explore existe para a pergunta que ninguém previu. Não é preciso criar
painel, salvar dashboard nem pedir permissão: abre-se uma consulta, olha-se o
resultado, refina-se.

Isso importa em diagnóstico porque a pergunta certa só aparece depois das duas
ou três erradas.

### 4. Fecha o ciclo: alerta, não só visualiza

Um visualizador exige que alguém esteja olhando. O alerting transforma a mesma
consulta em uma regra que observa sozinha, com estados, roteamento e
silenciamento.

## Pontos fracos

### 1. Não enxerga o código-fonte

Este é o limite mais importante para uma disciplina de manutenção de software,
e precisa ser dito com todas as letras: **o Grafana mostra sintoma em execução,
não causa no código.**

Ele não detecta code smell, não mede acoplamento, não encontra dívida técnica,
não acha vulnerabilidade, não sugere refatoração.

Na nossa demo, o Grafana chega até a mensagem do Postgres: `null value in
column "name" ... violates not-null constraint`. Isso é muito, e é onde ele
para. Ele **não** aponta a linha do serviço que deixou de validar `name`, não
diz se falta um `if` ou um schema de validação, e não sabe se o mesmo descuido
se repete em outros lugares do código. Essas perguntas são de quem lê o código,
com ajuda de análise estática, de revisão e de depurador.

Uma frase que vale dizer: **o Grafana estreita a busca de "o sistema inteiro"
para "esta chamada"; quem fecha a distância entre "esta chamada" e "esta linha"
é outra ferramenta.**

Uma equipe que confunde observabilidade com qualidade de código termina com
dashboards excelentes sobre um sistema que continua difícil de manter.

### 2. Depende inteiramente de instrumentação

O Grafana não coleta nada. Se a aplicação não emite métrica, não escreve log
estruturado e não propaga contexto de trace, não há o que visualizar — e
nenhuma configuração do Grafana resolve isso.

A demo funciona bem porque a aplicação de exemplo já vem instrumentada com
OpenTelemetry. Em um sistema legado real, essa é a maior parte do custo de
adoção: alguém precisa entrar no código e instrumentá-lo, e propagar contexto
de trace entre serviços é justamente o tipo de mudança transversal que dá
trabalho.

Há um paradoxo aqui que vale mencionar: a ferramenta que ajuda a manter
software legado exige, para funcionar, exatamente o tipo de modificação que o
software legado torna caro.

### 3. Curva de aprendizado fragmentada

"Aprender Grafana" não é uma coisa só. Cada fonte tem sua própria linguagem de
consulta:

| Fonte | Linguagem |
|---|---|
| Mimir / Prometheus | PromQL |
| Loki | LogQL |
| Tempo | TraceQL |
| Bancos relacionais | SQL |

São quatro sintaxes com semânticas diferentes, e a interface do Grafana é a
mesma para todas — o que dá a impressão enganosa de que é tudo igual. Na
prática, alguém confortável com PromQL ainda vai apanhar de TraceQL.

O editor visual ajuda no começo e atrapalha depois: consultas de verdade
acabam escritas em modo texto.

### 4. Proliferação de dashboards

Criar painel é fácil. Essa é a virtude e o problema.

Instalações maduras acumulam dezenas ou centenas de dashboards: quase
duplicados, criados para um incidente específico e nunca apagados, quebrados
porque a métrica que consultavam foi renomeada. Ninguém sabe qual é o
canônico, e a resposta para "onde vejo a latência do serviço X" passa a ser
"depende de quem você perguntar".

Este é um problema de manutenção **criado pela própria ferramenta**.

E não é preciso ir longe para achar um exemplo: **no dashboard oficial que a
nossa demo usa, um painel está com a unidade errada.** O painel
`All Endpoint Latencies in ms (Last 10 mins)` calcula a média de
`traces_spanmetrics_latency_sum / _count`, que o Tempo emite em **segundos**, e
não declara unidade nenhuma no `fieldConfig`. O título diz milissegundos e o
número mostrado são segundos — um erro de fator 1000, em um dashboard mantido
pela própria Grafana Labs. O painel vizinho,
`Top 10 Highest Endpoint Latencies`, usa a mesma métrica e declara
`unit: s` corretamente.

Vale mostrar isso na apresentação. É um dashboard que mente em silêncio: não dá
erro, não fica vermelho, ninguém percebe. É exatamente o apodrecimento que o
parágrafo seguinte descreve.

Vale fechar o ponto ligando ao que foi dito no bloco de abertura:

> É por isso que o Git Sync existir na versão 13 é relevante: dashboard é
> software, apodrece como software, e precisa de versionamento e revisão como
> software. O Grafana Advisor é a admissão do mesmo problema pelo outro lado —
> uma ferramenta que varre a instância procurando dívida técnica na camada de
> observabilidade.

## Quando não usar

Pergunta provável da turma ou do professor. Resposta curta:

- Quando não há instrumentação e não há orçamento para criá-la.
- Quando a pergunta é sobre o código em repouso, e não sobre o sistema em
  execução: aí a ferramenta certa é análise estática, revisão de código ou
  profiler.
- Quando o time precisa de captura de exceção ligada a release e commit, com
  agrupamento automático de erro por stack trace — esse é o desenho de uma
  ferramenta centrada em exceção, não de uma camada de consulta.
