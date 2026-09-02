# 03 — Escopo e fronteiras

Cada item da lista do professor foi para um grupo diferente. Mostrar o Grafana
sem invadir o território de ninguém é, depois da própria demonstração, o
requisito mais importante deste trabalho.

O enquadramento é positivo e deve ser dito em voz alta na apresentação:
**entender onde uma ferramenta para e outra começa é sinal de maturidade
técnica, não de escopo reduzido.** Uma equipe que sabe passar o bastão para a
ferramenta certa resolve mais rápido do que uma que tenta esticar a ferramenta
que já tem.

E a fronteira não é só uma frase no slide. Ela está implementada nos scripts.

## As três fronteiras

### Profiling contínuo (Pyroscope) — grupo de Profilers

O stack de demonstração **já vem com o Pyroscope instalado**. O Alloy coleta
perfis de CPU e memória dos três microsserviços e os envia para lá, o
Pyroscope está provisionado como fonte de dados no Grafana e o plugin
`grafana-pyroscope-app` aparece no menu lateral como "Profiles".

Nossa investigação para no nível de **serviço, endpoint e span**. Descobrir
qual função dentro do span consome o tempo é profiling, e profiling é de outro
grupo.

### Sentry — grupo de observabilidade centrada em exceção

O Sentry também está fora. A distinção que interessa é arquitetural e cabe em
duas frases:

> O Sentry é centrado em exceção: um SDK dentro da aplicação captura o erro no
> momento em que ele acontece e o liga à release e ao commit que o
> introduziram. O Grafana não coleta nada — é uma camada de consulta e
> visualização sobre fontes de dados de terceiros, agnóstica ao tipo de sinal.

Isso posiciona o Grafana e encerra o assunto. Nenhuma funcionalidade do Sentry
é demonstrada ou detalhada.

### k6 — ferramenta de teste

O k6 é da Grafana Labs, mas é ferramenta de teste de carga, e o enunciado veta
ferramentas de teste. Ele não aparece na demo nem é citado como algo que
usamos.

O detalhe crítico é que **o k6 sobe por padrão** no `docker-compose.yml`
oficial, com `restart: always`, rodando um script de carga contra a aplicação.
Por isso todos os scripts sobem o stack com `--scale k6=0`.

A carga da demonstração vem do `mythical-requester`, um microsserviço do
próprio exemplo que gera tráfego e erros continuamente. Não precisamos de
gerador de carga nenhum.

## Checklist operacional

Marque tudo antes do ensaio geral e de novo antes de apresentar.

### 1. O stack sobe com `--scale k6=0`, sempre

- [ ] Nenhum script sobe o stack sem isso.
- **Implementado em:** `stack/_comum.sh`, função `subir_sem_k6()`. É a única
  porta de entrada para `up`; `record.sh` e `restore.sh` chamam ela.
- **Verificado por:** `make verify`, checagem "k6 FORA do ar (escopo do
  trabalho)". `record.sh` e `restore.sh` também abortam se o k6 subir.
- **Risco residual:** rodar `docker compose up` na mão. `make setup` avisa
  sobre isso explicitamente.

### 2. O dashboard da demo é uma cópia; o original não é aberto

- [ ] Existe um dashboard chamado, por exemplo, `MLT — Demo` salvo na
  instância, e é ele que está nos favoritos.
- **Por que a cópia é obrigatória:** o `MLT Dashboard` original é *provisionado
  por arquivo* (`grafana/provisioning/dashboards/mlt.yaml`, com
  `editable: false`). O Grafana não deixa salvar alterações nele. Qualquer
  ajuste que a demo precise — remover um painel, fixar um intervalo, mudar a
  ordem — só sobrevive em uma cópia salva no banco interno do Grafana.
- **Nota de realidade, verificada neste commit do repositório oficial:** os
  dashboards provisionados **não contêm painel de profiling**. Não há
  referência a Pyroscope, perfil ou flame graph em nenhum dos quatro arquivos
  de `grafana/definitions/`. Ou seja: não há painel de profiling para remover.
  A cópia continua sendo feita, pelo motivo do parágrafo anterior, e a
  verificação a fazer na cópia é a do item 3.
- **O que existe e precisa ficar de fora:** o dashboard provisionado
  **"Official k6 Test Result"**, que aparece na lista de dashboards do Grafana.
  Ele é de teste de carga. Não abra, não navegue pela lista de dashboards com
  o projetor ligado — vá direto pelo favorito.

### 3. O link "trace to profiles" não é clicado

- [ ] Ninguém clica em nada que leve a perfil ao abrir um span.
- **Nota de realidade, verificada na instância em execução:** a fonte de dados
  Tempo **não tem `tracesToProfiles` configurado** (só `tracesToLogs`,
  `serviceMap` e `nodeGraph`). O feature toggle `traceToProfiles` está ligado
  no Compose, mas sem a configuração na fonte de dados o botão de perfil não
  aparece no painel de detalhe do span. Confirme durante o ensaio; se aparecer
  em alguma versão futura, o botão fica no painel lateral que abre ao clicar
  em um span, junto de "Logs for this span".
- **Onde o risco realmente está:** no menu lateral esquerdo. O plugin
  `grafana-pyroscope-app` está habilitado e coloca uma entrada **"Profiles"**
  na navegação, logo abaixo de Explore. Não clique.

### 4. A fonte de dados Pyroscope não é aberta no Explore

- [ ] Nenhuma aba do roteiro aponta para o Pyroscope.
- [ ] O seletor de fonte de dados do Explore fica em Loki ou Tempo o tempo
  todo.
- A fonte `pyroscope` existe e está saudável. Ela simplesmente não faz parte
  do nosso roteiro.

### 5. A demo termina no span e passa o bastão explicitamente

- [ ] A frase de fechamento foi ensaiada.
- A investigação termina em: serviço, endpoint, span com erro e dependência
  culpada. A fala de amarração está em `05-roteiro-apresentacao.md` e entrega
  o passo seguinte ao grupo de Profilers de forma cordial, como encadeamento
  entre ferramentas.

### 6. O Sentry aparece só como distinção arquitetural

- [ ] Uma ou duas frases, no bloco de abertura ou na conclusão.
- [ ] Nenhuma tela, nenhuma funcionalidade, nenhuma comparação item a item.

## Resumo em uma tabela

| Assunto | Nosso escopo | De outro grupo |
|---|---|---|
| Métrica, log, trace correlacionados | sim | — |
| Dashboard, variável de template, Explore | sim | — |
| Regra de alerta e ciclo de estados | sim | — |
| Perfil de CPU e memória, flame graph | — | Profilers (Pyroscope, perf) |
| Captura de exceção ligada a release e commit | — | Sentry |
| Geração de carga, teste de desempenho | — | vetado pelo enunciado (k6) |
