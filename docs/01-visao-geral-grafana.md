# 01 — Visão geral do Grafana

## Em uma frase

O Grafana é uma camada de visualização, consulta e alerta sobre dados que ele
não coleta nem armazena.

Essa frase é a definição inteira, e vale repetir na apresentação porque é o que
separa o Grafana da maioria das ferramentas com as quais ele é confundido. Não
há agente do Grafana rodando dentro da aplicação. Não há banco de dados do
Grafana guardando métricas. O que existe é um servidor que sabe conversar com
mais de cem sistemas diferentes, traduzir a pergunta do usuário para a
linguagem nativa de cada um e desenhar a resposta.

## Arquitetura em três peças

### 1. Data sources

Um *data source* é uma conexão configurada para um sistema que já guarda dados:
Prometheus, Mimir, Loki, Tempo, Elasticsearch, PostgreSQL, MySQL, InfluxDB,
CloudWatch, BigQuery. O Grafana mantém um plugin por tipo de fonte; o plugin
sabe montar a requisição no dialeto certo e converter o resultado para um
formato interno comum (o *data frame*).

A consequência prática é que a mesma tela pode juntar um gráfico de métricas
vindo do Mimir com uma tabela vinda do PostgreSQL, sem que o dado precise ser
copiado para lugar nenhum.

No stack da nossa demonstração há cinco fontes provisionadas: Mimir (métricas),
Loki (logs), Tempo (traces), PostgreSQL (banco da aplicação) e Pyroscope
(perfis — fora do nosso escopo, ver `03-escopo-e-fronteiras.md`).

### 2. Dashboards e painéis

Um painel é uma consulta mais uma visualização. A consulta é escrita na
linguagem da fonte: PromQL para Mimir, LogQL para Loki, TraceQL para Tempo, SQL
para bancos relacionais. A visualização é escolhida à parte — série temporal,
tabela, mapa de calor, gauge, histograma, grafo de nós.

Dashboards têm **variáveis de template**: valores nomeados que aparecem como
seletores no topo da tela e são interpolados nas consultas. No dashboard que
usamos na demo, `httpEndpoint`, `httpStatus` e `serviceVersion` são variáveis
alimentadas por consultas de rótulo ao Tempo. Trocar o valor no seletor
reescreve todas as consultas da tela de uma vez. É o que transforma um
dashboard de "relatório fixo" em ferramenta de investigação.

### 3. Alerting

Regras de alerta são construídas sobre as mesmas consultas dos painéis. Uma
regra tem uma consulta, uma condição (por exemplo, "acima de 5%"), um período
de avaliação e um período de pendência. O estado percorre `Normal`, `Pending`,
`Alerting` e `Resolved`, com `No Data` e `Error` como estados especiais.

Alertas disparados são roteados por *notification policies*, que casam rótulos
da regra com pontos de contato (e-mail, Slack, PagerDuty, webhook). Também é
possível silenciar temporariamente uma regra sem desligá-la, o que importa
durante uma janela de manutenção planejada.

O alerting é a peça que fecha o ciclo: sem ele, o Grafana seria só um
visualizador, e alguém precisaria estar olhando a tela para descobrir um
problema.

## De onde veio

O Grafana foi criado em 2014 por Torkel Ödegaard, como um fork do Kibana. A
motivação era simples: o Kibana da época era bom para logs do Elasticsearch e
ruim para métricas de séries temporais. O fork nasceu para desenhar métricas
bem, e a decisão de arquitetura que o definiu foi não trazer banco de dados
junto.

Nos anos seguintes a Grafana Labs construiu o resto da pilha ao redor, o que
hoje é chamado de **stack LGTM**:

| Letra | Componente | Sinal |
|---|---|---|
| L | Loki | logs |
| G | Grafana | visualização |
| T | Tempo | traces |
| M | Mimir | métricas |

Vale notar a assimetria: Loki, Tempo e Mimir são bancos; o Grafana é a
interface. Os três podem ser usados sem o Grafana, e o Grafana pode ser usado
sem nenhum dos três.

## Versão 13

A versão atual é a 13, anunciada no GrafanaCON 2026. Três novidades importam
para uma disciplina de manutenção de software:

- **Git Sync em disponibilidade geral.** Dashboards passam a ser versionados
  em um repositório Git, com o Grafana lendo e escrevendo daquele repositório.
  O argumento é discutido em `02-grafana-e-manutencao-de-software.md`.
- **Grafana Advisor.** Uma ferramenta que inspeciona a própria instância em
  busca de problemas de configuração, plugins depreciados e fontes de dados
  quebradas. É análise estática aplicada à camada de observabilidade.
- **Grafana Assistant fora do Cloud.** O assistente de linguagem natural, que
  ajuda a escrever consultas e montar painéis, deixou de ser exclusivo da
  oferta gerenciada.

## O que mostrar no slide de abertura

Um diagrama de três caixas basta:

```
   aplicação instrumentada
            |
            v
   [ Alloy / coletor ]  ---> Mimir (métricas)
                        ---> Loki  (logs)
                        ---> Tempo (traces)
                               ^
                               | consulta
                        [  GRAFANA  ]
                               |
                        dashboards, Explore, alertas
```

A seta que importa é a de baixo, e ela aponta para cima: o Grafana **puxa**.
Nada de dado passa por ele no caminho de escrita.
