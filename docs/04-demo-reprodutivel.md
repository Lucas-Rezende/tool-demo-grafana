# 04 — A demo reprodutível

Este é o documento mais importante do repositório.

O requisito é simples de enunciar e chato de cumprir: **a demonstração precisa
ser idêntica ao ensaio e não pode exigir 40 minutos de aquecimento antes da
aula.** O stack `intro-to-mltp` leva um tempo considerável até acumular dados
suficientes para os painéis ficarem interessantes, e um dashboard vazio no
projetor destrói a apresentação.

A solução é congelar um dataset.

1. Gravamos uma janela de ~45 minutos de dados, uma vez.
2. Paramos o stack e exportamos os volumes do Docker para tarballs.
3. No dia, restauramos os volumes e subimos o stack em 2 a 3 minutos, com
   exatamente os mesmos dados do ensaio.
4. Os dashboards e as URLs usam **intervalo de tempo absoluto**, apontando para
   a janela gravada, e ficam salvos como favoritos na ordem do roteiro.

## As armadilhas do repositório oficial

Todas foram verificadas no commit fixado em `stack/_comum.sh`. Se você atualizar
o commit, verifique de novo.

### Armadilha 1 — Loki, Tempo e Mimir não têm volume nenhum

O `docker-compose.yml` oficial declara apenas dois volumes nomeados, `grafana`
e `postgres`. Loki, Tempo e Mimir recebem só *bind mounts* de configuração. Os
dados que eles gravam vivem na camada gravável do container e são destruídos em
qualquer `docker compose down`.

Sem criar volumes nomeados para os três, **não existe dataset para congelar**.

Há uma segunda camada nessa armadilha: o volume `grafana` é *declarado* no
arquivo oficial, mas **não é montado em serviço nenhum**. O serviço `grafana` só
tem os dois bind mounts de dashboards e provisionamento. Ou seja, o banco
interno do Grafana — onde ficam os dashboards salvos pela interface, as regras
de alerta e os plugins baixados — também está na camada gravável.

`stack/docker-compose.override.yml` resolve os dois problemas:

| Serviço | Caminho montado | Por quê |
|---|---|---|
| `grafana` | `/var/lib/grafana` | banco interno: dashboard copiado, regras de alerta, plugins |
| `loki` | `/loki` | `path_prefix: /loki`, chunks em `/loki/chunks` |
| `tempo` | `/tmp/tempo` | WAL, blocos e WAL do metrics-generator |
| `mimir` | `/tmp/mimir` | TSDB, compactor e regras |

#### Efeito colateral: o Tempo não sobe com o volume montado

Corrigir a armadilha 1 cria um problema novo, e ele é traiçoeiro.

Quando o caminho já existe na imagem, o Docker copia conteúdo **e dono** da
imagem para o volume vazio. É o que acontece com `/loki` (uid 10001) e
`/var/lib/grafana` (uid 472) — por isso esses dois funcionam de primeira. O
Mimir roda como root e também não se importa.

O Tempo é a exceção: `/tmp/tempo` **não existe** na imagem, só `/tmp`. O volume
nomeado nasce `root:root 0755`, o processo do Tempo roda como uid 10001, e o
container morre no boot:

```
failed to init module services: error initialising module: store:
failed to create store: mkdir /tmp/tempo/blocks: permission denied
```

O sintoma é cruel: o resto do stack sobe normalmente, o dashboard desenha, os
logs aparecem, e só os traces não existem. Ou seja, exatamente o clímax da
apresentação.

A função `preparar_volumes()` em `stack/_comum.sh` resolve: ela cria os volumes
antes do `up` e ajusta o dono do volume do Tempo para `10001:10001`. É chamada
automaticamente por `subir_sem_k6()`, então tanto `record.sh` quanto
`restore.sh` já fazem isso.

A verificação de container `tempo` no `make verify` existe para pegar esse caso.

### Armadilha 2 — a retenção do Tempo é de 1 hora

`tempo/tempo.yaml` traz `block_retention: 1h`, em **dois lugares** (dentro de
`backend_scheduler.provider.compaction.compaction` e em
`overrides.defaults.compaction`).

Com esse valor, todo trace gravado na véspera é apagado assim que o Tempo sobe
no dia seguinte. Métricas e logs continuam lá, o dashboard desenha normalmente,
e o grupo só descobre o problema no momento de clicar no trace ID na frente da
turma — que é justamente o clímax da apresentação.

`stack/setup.sh` faz backup do arquivo em `tempo.yaml.original` e troca os dois
valores por `336h` (14 dias). O script confere que sobraram zero ocorrências de
`1h` e avisa se o número de ocorrências mudar em relação ao esperado.

Cuidado ao editar à mão: existe uma chave parecida logo abaixo,
`compacted_block_retention`, que é outra coisa e não deve ser alterada. O `sed`
do `setup.sh` está ancorado no início da linha justamente por isso.

### Armadilha 3 — o Tempo não busca em dados com menos de 15 minutos

Esta é a mais sutil das armadilhas, e a que mais tempo custou a descobrir.

O Tempo divide a busca em dois caminhos: dados recentes vêm do *live-store*
(memória e WAL), dados antigos vêm dos blocos no armazenamento. A fronteira é
`query_frontend.search.query_backend_after`, que vale **15 minutos** por padrão.

Depois de um `restore`, o live-store está vazio — todo o dataset está nos
blocos. Se a janela congelada tiver menos de 15 minutos de idade, a busca por
traces devolve zero resultados, sem erro nenhum: o Tempo simplesmente não olha
para os blocos naquele intervalo.

No dia da apresentação isso não apareceria, porque a janela terá dias. O
problema é que o **ensaio** logo depois de congelar parece um fracasso
completo, e o grupo vai procurar defeito onde não tem.

`stack/setup.sh` reduz o valor para `1m`. Não dá para zerar: o Tempo se recusa a
subir com

```
QueryBackendAfter (0s) must be greater than query end cutoff (30s)
```

### Armadilha 4 — o `up` devolve o controle com containers parados

O `mythical-requester` e o `mythical-recorder` dependem do healthcheck da fila
RabbitMQ. Em algumas execuções o `docker compose up -d` devolve o controle com
os dois ainda em estado `Created`, sem nunca iniciá-los. O stack parece no ar,
mas a aplicação não gera tráfego nenhum.

A função `subir_sem_k6()` usa `--wait --wait-timeout 240` justamente por isso, e
o `make verify` confere serviço por serviço.

### Armadilha 5 — o k6 sobe sozinho e não morre

O serviço `k6` está no compose com `restart: always`. Subir o stack sem
`--scale k6=0` deixa um teste de carga rodando indefinidamente contra a
aplicação — o que, além de estar fora do escopo do trabalho (ver
`03-escopo-e-fronteiras.md`), polui o dataset com tráfego sintético.

### Armadilha 6 — o Grafana baixa plugins da internet a cada boot

O serviço usa `GF_INSTALL_PLUGINS` com plugins de app. Sem persistência, esse
download acontece em toda inicialização e a demo passa a depender do Wi-Fi da
sala.

Com o volume nomeado em `/var/lib/grafana` (armadilha 1), os plugins são
baixados uma vez, durante a gravação, e ficam congelados junto com o resto. O
override ainda desliga o feed de notícias, a checagem de atualização e a
telemetria, que são as outras chamadas externas que o Grafana faz na
inicialização.

Detalhe conveniente: o Compose oficial já define `GF_AUTH_ANONYMOUS_ENABLED=true`
com papel `Admin` e formulário de login desabilitado. Não há senha para digitar
no projetor.

## Etapa 1 — preparação (uma vez por máquina)

```bash
make setup
```

> Sem `make` instalado (é o caso do Git for Windows padrão), troque todo
> `make <alvo>` deste documento por `./stack/<alvo>.sh`. O resultado é o mesmo.

O script clona o `grafana/intro-to-mltp` em `intro-to-mltp/`, fixa o commit
registrado em `stack/_comum.sh`, aplica os dois ajustes no `tempo/tempo.yaml`
(retenção de blocos e `query_backend_after`), avisa sobre o k6 e sobre o
dashboard do k6, e baixa todas as imagens. Ao final grava `stack/.setup-info`
com o que foi fixado.

O `tempo.yaml` original fica guardado em `tempo/tempo.yaml.original`, e o
script é idempotente: rodar de novo não duplica nada.

> Nunca rode `git pull` dentro de `intro-to-mltp/`. Isso desfaz os dois ajustes
> e o sintoma só aparece na hora de abrir um trace. Se acontecer, rode
> `make setup` outra vez.

Fixar o commit importa: o repositório oficial recebe commits com frequência e já
mudou o esquema dos dashboards. Sem isso, o ensaio e a apresentação podem ver
stacks diferentes.

Opcionalmente, fixe também as imagens da aplicação:

```bash
make pin
```

As imagens `mythical-*` usam tags mutáveis (terminadas em `-latest`). O comando
imprime os digests para colar em `stack/docker-compose.override.yml`, garantindo
que o dia da apresentação use exatamente a imagem do ensaio.

## Etapa 2 — gravação da janela (~45 minutos, uma vez)

```bash
make record        # ou: make record-zero, para apagar os volumes antes
```

O script sobe o stack sem o k6, espera o Grafana responder, confere que o k6
não subiu e imprime o **epoch em milissegundos do início da janela**. Esse
número é anotado em `snapshot/janela.env` e precisa ser copiado para
`stack/JANELA.md`.

Enquanto os 45 minutos correm, monte o que precisa ficar salvo dentro do
Grafana — tudo isso vive no volume `grafana` e será congelado junto:

1. **A cópia do dashboard.** Abra o `MLT Dashboard` e use *Export* / *Import*
   (ou "Save as") para criar a cópia. O original é provisionado e não aceita
   alterações salvas.
2. **As duas regras de alerta**, descritas na seção sobre alertas mais abaixo.
3. **Nada de Pyroscope e nada do dashboard do k6** (ver
   `03-escopo-e-fronteiras.md`).

Não é preciso gerar carga: o `mythical-requester` produz tráfego e erros
sozinho, continuamente.

> **O `snapshot/` distribuído para o grupo já vem com os três itens prontos.**
> Só é preciso refazê-los se vocês regravarem a janela do zero. O que existe
> lá dentro está descrito na seção "O que já vem pronto no snapshot", no fim
> deste documento.

Passados os ~45 minutos:

```bash
make freeze
```

O `freeze.sh` roda `docker compose stop` — **nunca `down`** — e exporta cada
volume para `snapshot/<nome>.tgz`. O `stop` cumpre dois papéis: preserva a
camada gravável dos containers e garante que os processos fecharam os arquivos
antes do `tar`, o que evita exportar um bloco de TSDB corrompido.

Ao final, `snapshot/congelado-em.txt` e `snapshot/janela.env` guardam os dois
epochs da janela. Copie-os para `stack/JANELA.md`.

> `snapshot/` não vai para o Git. Combine com o grupo como compartilhar o
> dataset: pendrive, Drive ou zip no Classroom.

## Etapa 3 — as URLs congeladas

Este é o truque que faz a demo parecer suave.

Todo link do Grafana carrega o intervalo de tempo na própria URL. Com dados
congelados, `from=now-1h` aponta para um período **depois** do fim da janela, e
o painel aparece vazio. A solução é usar epoch absoluto:

```
http://localhost:3000/d/<uid>/<slug>?orgId=1&from=1788309385603&to=1788312085603
```

Regras:

- `from` e `to` sempre em epoch **milissegundos**. Nunca `now-*`.
- Fixe as variáveis de template na URL com `&var-httpEndpoint=/unicorn`,
  `&var-httpStatus=500` e assim por diante. Isso evita que o seletor volte para
  "All" ao recarregar.
- Para o Explore, o parâmetro é o `panes`, que já vem preenchido quando você
  copia a URL da barra de endereços com o intervalo absoluto selecionado.
- Salve cada link como **favorito do navegador, numerado na ordem do roteiro**.
  No dia, a demo vira uma sequência de cliques na barra de favoritos, sem
  digitação e sem mexer no seletor de tempo.

Nada disso precisa ser montado à mão:

```bash
ENDPOINT=/unicorn TRACE=<trace-id> make urls
```

O `stack/urls.sh` lê a janela de `snapshot/janela.env`, descobre o UID da regra
de alerta sintética pela API do Grafana, imprime as sete URLs na ordem do
roteiro e grava `snapshot/favoritos.html` — um arquivo de favoritos importável
no Chrome, no Edge ou no Firefox (Favoritos → Gerenciar → Importar de arquivo
HTML).

A tabela para preencher está em [`stack/JANELA.md`](../stack/JANELA.md).

Aviso sobre as variáveis de template do `MLT Dashboard`: elas são consultas de
**rótulo ao Tempo** (`url.path`, `http.response.status_code`,
`service.version`), com atualização a cada mudança de intervalo. Se o intervalo
do dashboard cair fora da janela gravada, os seletores voltam vazios e os
painéis somem. Mais um motivo para nunca tocar no seletor de tempo ao vivo.

## Etapa 4 — ensaio geral

Rode o ciclo completo pelo menos uma vez, em outra máquina se possível:

```bash
make restore
make verify
```

O `restore.sh` derruba os containers, **remove e recria** os volumes, restaura
os tarballs, sobe o stack sem o k6, espera o `/api/health` do Grafana responder
com `database: ok` e então aquece as fontes de dados: ele repete a consulta ao
Loki e ao Tempo na janela congelada até as duas responderem. Sem essa espera,
um `make verify` disparado imediatamente acusa falha no Loki e no Tempo apenas
porque o índice e a lista de blocos ainda estavam carregando.

Ele é idempotente: rodar dez vezes seguidas produz o mesmo resultado, porque os
volumes são sempre recriados do zero. O ciclo completo leva de 1 a 2 minutos.

O `verify.sh` é o teste de cinco minutos. Ele recebe a janela (ou lê de
`snapshot/janela.env`) e consulta as quatro fontes, imprimindo um semáforo:

```
Containers
  [ OK ] serviço grafana no ar
  ...
  [ OK ] k6 FORA do ar (escopo do trabalho)

Fontes de dados na janela congelada
  [ OK ] Grafana  — /api/health
  [ OK ] Mimir    — traces_spanmetrics_calls_total
  [ OK ] Mimir    — mythical_request_times_bucket
  [ OK ] Loki     — linhas de log
  [ OK ] Loki     — linhas com status=Error
  [ OK ] Tempo    — traces na janela
  [ OK ] Tempo    — spans com erro
```

A checagem de traces no Tempo é a que mais importa: se só ela falhar, quase
certamente a retenção voltou para `1h`.

Depois do semáforo verde, abra os sete favoritos em sequência e cronometre.
Ensaie também as trocas de bastão.

## Etapa 5 — dia da apresentação

```bash
make restore
make verify
```

Dois comandos, 2 a 3 minutos. Depois disso, só favoritos.

Lembre que o stack **continua gerando dados novos** depois do restore. Isso não
atrapalha, porque todos os links usam intervalo absoluto — mas é mais um motivo
para não trocar o seletor para "Last 5 minutes" no meio da demonstração.

Checklist final em [`stack/JANELA.md`](../stack/JANELA.md), seção 4.

## Alertas com dados congelados

Aqui há um problema real e ele precisa ser explicado, não escondido.

Um dashboard consulta o intervalo que você pedir, inclusive no passado. Uma
**regra de alerta não**: o motor de avaliação roda a consulta *agora*, a cada
intervalo de avaliação. São duas semânticas de tempo diferentes dentro da mesma
ferramenta, e é isso que a demo precisa deixar claro.

A consequência prática, medida na nossa janela:

| Momento | Estado da regra realista | Por quê |
|---|---|---|
| Logo após `make restore` | `Pending (NoData)` | o `increase(...[5m])` ainda não tem 5 minutos de dado novo |
| Depois de ~10 min no ar | `Normal` | o stack voltou a gerar tráfego e a regra passou a avaliar **esse** tráfego |

Repare no segundo caso: a regra **nunca** está avaliando a janela congelada que
está no dashboard ao lado. Ela avalia o presente, e o presente é o tráfego que
a aplicação começou a gerar quando o stack subiu.

Como o bloco 3 acontece uns 15 minutos depois do `restore`, o estado que vai
aparecer no projetor é normalmente `Normal`. Se a taxa de erro do tráfego novo
passar de 5%, pode aparecer `Pending` ou `Alerting`. Qualquer um dos três serve
para a fala — o que não pode acontecer é o grupo prometer um estado e a tela
mostrar outro.

A demo usa **duas regras**, por motivos diferentes.

### Regra 1 — realista, para explicar a anatomia e a semântica de tempo

Escrita sobre a métrica de erro do serviço, a mesma do painel do dashboard:

```promql
(
  sum(increase(traces_spanmetrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m]))
  /
  sum(increase(traces_spanmetrics_calls_total{status_code!=""}[5m]))
) * 100
```

com condição `IS ABOVE 5`, período de pendência de 5 minutos e
`noDataState: NoData`.

Ela serve para mostrar, no editor de regras, **as três partes de um alerta** —
a consulta, a condição e o roteamento da notificação — e para explicar a
diferença de semântica de tempo entre painel e regra.

Nomeie-a de forma direta: `Taxa de erro acima de 5%`.

### Regra 2 — sintética, para mostrar a transição ao vivo

Uma regra sobre a fonte de dados **Mimir** com a expressão:

```promql
vector(1)
```

e condição `IS ABOVE 0`.

`vector(1)` é uma função do PromQL que devolve o valor constante 1 no instante
avaliado. Ela não depende de dado nenhum: funciona em qualquer máquina, com
qualquer janela, inclusive com o Mimir recém-restaurado. Com intervalo de
avaliação de 10 segundos e período de pendência de 30 segundos, o ciclo
`Normal → Pending → Alerting` acontece em menos de um minuto — verificado.

**Nomeie de forma honesta.** A que está no snapshot chama-se:

```
[SINTÉTICA] Demonstração de transição de estado — não é uma condição real
```

Dizer em voz alta que a regra é sintética e por quê custa cinco segundos e é a
diferença entre uma demo bem-feita e uma demo que engana. O motivo é bom: ela
existe para tornar visível o ciclo de estados, que é o que estamos ensinando.

### Onde as regras ficam guardadas

No banco interno do Grafana, em `/var/lib/grafana` — o volume que o nosso
override monta. Elas são criadas durante a gravação e viajam dentro de
`snapshot/grafana.tgz`. Não é preciso recriá-las no dia.

## O que já vem pronto no snapshot

O `snapshot/` distribuído para o grupo não tem só os dados: tem também o estado
do Grafana, porque o banco interno dele viaja dentro de `grafana.tgz`. Isso
significa que estes objetos já existem depois de um `make restore`.

### Pasta `Tool Demo`

Separa o material da demo do que é provisionado pelo repositório oficial. Fica
visível na lista de dashboards e na de alertas.

### Dashboard `MLT Demo (Tool Demo DCC-UFMG)`

- UID `mlt-demo`, URL `/d/mlt-demo/mlt-demo-tool-demo-dcc-ufmg`.
- Cópia editável do `MLT Dashboard`: os mesmos 8 painéis e as mesmas 3
  variáveis de template (`httpStatus`, `httpEndpoint`, `serviceVersion`).
- Intervalo padrão já absoluto, apontando para a janela gravada.
- Auto-refresh desligado, porque dado congelado não muda e o refresh só
  produz requisição inútil no meio da apresentação.

Foi criado com a API, não pela interface, para que o processo fique
reproduzível:

```bash
curl -s http://localhost:3000/api/dashboards/uid/<uid-do-original> \
  > copia.json
# trocar uid, title e time; remover id; depois:
curl -s -X POST http://localhost:3000/api/dashboards/db \
  -H 'Content-Type: application/json' --data-binary @copia.json
```

Detalhe que economiza tempo: o dashboard original está no esquema novo
(`dashboard.grafana.app/v2`), mas a API antiga (`/api/dashboards/uid/...`)
devolve a conversão para o esquema clássico, e é essa conversão que dá para
salvar de volta.

### As duas regras de alerta

No grupo `demo`, com intervalo de avaliação de **10 segundos** — o mínimo que o
Grafana aceita, e o que torna a transição de estado visível ao vivo.

| Regra | Condição | Pending | Comportamento na demo |
|---|---|---|---|
| `Taxa de erro acima de 5%` | erro % `> 5` sobre `traces_spanmetrics_calls_total` | 5m | `Pending (NoData)` nos primeiros minutos, `Normal` depois |
| `[SINTÉTICA] Demonstração de transição de estado — não é uma condição real` | `vector(1) > 0` | 30s | `Normal → Pending → Alerting` em ~40 s |

As duas foram criadas por
`POST /api/v1/provisioning/alert-rules` com o cabeçalho
`X-Disable-Provenance: true`, que é o que permite continuar editando as regras
pela interface depois. Sem esse cabeçalho, o Grafana as marca como
provisionadas e trava a edição.

A descrição de cada regra, visível no detalhe dela, explica em texto por que
ela se comporta daquele jeito. Serve de cola durante a apresentação.

### `favoritos.html`

Gerado por `make urls`. Importe no navegador antes de apresentar.
