# 02 — Grafana e manutenção de software

Este é o eixo do trabalho. A ferramenta pode ser interessante por si só, mas a
nota vem de mostrar **por que ela pertence a uma disciplina de manutenção e
evolução**. Nada aqui pode ficar implícito na apresentação.

## Frase-síntese

> Observabilidade é o ciclo de feedback da evolução do software. Sem ela, toda
> mudança é feita no escuro.

Esta frase fecha o bloco de abertura e reaparece no slide de conclusão.

## Manutenção corretiva

A manutenção corretiva clássica supõe que o defeito é reproduzível: escreve-se
um teste que falha, corrige-se, o teste passa. Uma parte grande dos defeitos em
sistemas distribuídos não se comporta assim. Eles dependem de volume de dados
real, de concorrência real, de latência de rede real e de um estado acumulado
que não existe na máquina de quem desenvolve.

O caso da nossa demo é exatamente esse. Cerca de 5% das requisições falham com
500, espalhadas por todos os endpoints, e a mensagem que o serviço de fachada
devolve não diz qual é a causa. A investigação percorre três sinais e derruba
duas hipóteses pelo caminho:

1. **Métrica.** Diz *que* existe erro (~5%) e, ao filtrar por endpoint com uma
   variável de template, derruba a primeira hipótese: os cinco endpoints ficam
   entre 4,24% e 4,99%, nenhum se destaca. O erro é transversal. A mesma tela
   mostra um segundo fato, aparentemente separado: a latência está na casa dos
   segundos.
2. **Log.** Derruba a segunda hipótese, que é a mais tentadora — a de que os
   5% que falham são justamente os lentos. Um `quantile_over_time` sobre o
   campo `dur`, agrupado por status, desenha duas linhas que se sobrepõem ao
   longo dos 45 minutos: `Ok` e `Error` têm a mesma distribuição de duração.
   Falhar e demorar são problemas independentes.
3. **Trace.** Responde as duas perguntas de uma vez. Quase todo o tempo da
   requisição está dentro de um único span, `pg.query:INSERT postgres`, e os
   middlewares da aplicação levam microssegundos. Os atributos desse span
   entregam o defeito: o SQL é `INSERT INTO owlbear(name) VALUES ($1)` e a
   mensagem é `null value in column "name" ... violates not-null constraint`
   (SQLSTATE 23502).

Ao final, "às vezes dá 500 e o sistema está lento" virou dois problemas
nomeados: falta validar `name` antes de chamar o banco, e a chamada ao banco
está demorando segundos. Isso é diagnóstico de manutenção corretiva feito sobre
um sistema em execução em vez de sobre um teste.

Vale notar o tipo do primeiro defeito: a regra violada não está no
código-fonte, está no schema do banco. Revisão de código e análise estática têm
dificuldade estrutural com esse tipo de defeito, porque a informação que
provaria o erro não está no arquivo que elas leem.

E vale notar o método: as duas hipóteses derrubadas valem tanto quanto a
resposta final. Corrigir o erro esperando que a latência melhorasse teria
custado uma sprint para descobrir que não melhorou nada.

## Manutenção perfectiva

Manutenção perfectiva é mudar código que funciona para que funcione melhor.
O risco característico é otimizar por intuição: a pessoa refatora a função que
*parece* pesada, ganha 3% e não percebe que 60% do tempo de resposta estava em
uma consulta ao banco disparada em outro lugar.

O Grafana entra aqui como instrumento de medição antes da mudança. O painel de
latência por endpoint e o painel de percentil 95 respondem "qual endpoint
realmente pesa" com dados de produção, não com palpite. Depois da mudança, os
mesmos painéis dizem se a intervenção teve efeito e de quanto.

O ponto a enfatizar: medir antes de mexer é uma prática de engenharia, e a
ferramenta é o que torna a prática barata o bastante para acontecer.

## Evolução

Evolução é a sequência de versões. Cada implantação é uma hipótese sobre o
comportamento futuro do sistema, e a maior parte dessas hipóteses nunca é
verificada.

O dashboard da demo tem uma variável de template chamada `serviceVersion`. Ela
existe porque os spans carregam o rótulo `service.version`, o que permite
separar os mesmos painéis por versão implantada. Com isso, a pergunta "a versão
nova ficou mais lenta?" tem resposta em dois cliques, e não em uma discussão.

É o mesmo raciocínio de comparação que se aplica a canary releases e a feature
flags: a mudança é observada, não apenas entregue.

## Dois ganchos recentes que reforçam o argumento

### Git Sync: artefatos de observabilidade também são software

Na versão 13, o Git Sync ficou disponível em geral. Dashboards passam a viver
em um repositório Git, com histórico, revisão em pull request e possibilidade
de reverter.

O argumento para a disciplina é direto: um dashboard **é** software. Ele tem
dependências (as fontes de dados e os nomes de métricas que consulta), sofre
com mudanças externas (renomear um rótulo quebra o painel silenciosamente),
apodrece quando ninguém mexe e acumula dívida técnica. Tratar dashboard como
configuração descartável, editada na interface por quem passar por ali, é
exatamente o que produz o problema descrito no próximo parágrafo.

### Grafana Advisor: dívida técnica na camada de observabilidade

O Advisor varre a instância procurando fontes de dados quebradas, plugins
depreciados e configurações problemáticas. É a mesma ideia de uma ferramenta de
análise estática, aplicada à instância de observabilidade em vez de ao código
da aplicação.

A existência dele admite algo importante: a camada de observabilidade acumula
dívida técnica como qualquer outra parte do sistema. Isso conecta com o ponto
fraco de "proliferação de dashboards" discutido em `06-pontos-fortes-e-fracos.md`.

## Resumo para o slide

| Tipo de manutenção | Pergunta | O que o Grafana entrega |
|---|---|---|
| Corretiva | Onde está o defeito que não reproduz localmente? | Métrica → log → trace, até o span culpado |
| Perfectiva | O que realmente vale otimizar? | Latência e percentis por endpoint, medidos antes da mudança |
| Evolutiva | A versão nova melhorou ou piorou? | Mesmos painéis segmentados por `service.version` |
