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

### Armadilha 3 — o k6 sobe sozinho e não morre

O serviço `k6` está no compose com `restart: always`. Subir o stack sem
`--scale k6=0` deixa um teste de carga rodando indefinidamente contra a
aplicação — o que, além de estar fora do escopo do trabalho (ver
`03-escopo-e-fronteiras.md`), polui o dataset com tráfego sintético.

### Armadilha 4 — o Grafana baixa plugins da internet a cada boot

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

O script clona o `grafana/intro-to-mltp` em `intro-to-mltp/`, fixa o commit
registrado em `stack/_comum.sh`, corrige a retenção do Tempo, avisa sobre o k6 e
sobre o dashboard do k6, e baixa todas as imagens. Ao final grava
`stack/.setup-info` com o que foi fixado.

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

Enquanto os 45 minutos correm, use o tempo para montar o que precisa ficar
salvo dentro do Grafana — tudo isso vive no volume `grafana` e será congelado
junto:

1. **A cópia do dashboard.** Abra o `MLT Dashboard` e use *Export* / *Import*
   (ou "Save as") para criar `MLT — Demo`. O original é provisionado e não
   aceita alterações salvas.
2. **As duas regras de alerta**, descritas na seção sobre alertas mais abaixo.
3. **Nada de Pyroscope e nada do dashboard do k6** (ver
   `03-escopo-e-fronteiras.md`).

Não é preciso gerar carga: o `mythical-requester` produz tráfego e erros
sozinho, continuamente.

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
os tarballs, sobe o stack sem o k6 e espera o `/api/health` do Grafana
responder com `database: ok`. Ele é idempotente: rodar dez vezes seguidas
produz o mesmo resultado, porque os volumes são sempre recriados do zero.

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

Uma regra de alerta avalia uma consulta **agora**. Como os dados param no
passado, uma regra escrita sobre "os últimos 5 minutos" não encontra série
nenhuma e vai para o estado `No Data`, não para `Alerting`. Mostrar isso sem
explicar parece um erro; explicar transforma em conteúdo.

A demo usa **as duas saídas**, nesta ordem.

### Regra 1 — realista, para explicar a anatomia

Escrita sobre a métrica de erro do serviço, a mesma do painel do dashboard:

```promql
(
  sum(increase(traces_spanmetrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m]))
  /
  sum(increase(traces_spanmetrics_calls_total{status_code!=""}[5m]))
) * 100
```

com condição `IS ABOVE 5`.

Ela serve para mostrar, no editor de regras, **as três partes de um alerta**: a
consulta, a condição e o roteamento da notificação. Abra também o histórico da
regra com o intervalo absoluto da janela: ali dá para ver a série que teria
disparado.

O que ela **não** faz é mudar de estado ao vivo — e é exatamente isso que a
pessoa 3 explica: com dados congelados, o motor de avaliação olha para o
presente e não encontra dado. É uma limitação honesta da demo, não da
ferramenta.

Nomeie-a de forma direta, por exemplo `Taxa de erro acima de 5%`.

### Regra 2 — sintética, para mostrar a transição ao vivo

Uma regra sobre a fonte de dados **Mimir** com a expressão:

```promql
vector(1)
```

e condição `IS ABOVE 0`.

`vector(1)` é uma função do PromQL que devolve o valor constante 1 no instante
avaliado. Ela não depende de dado nenhum: funciona em qualquer máquina, com
qualquer janela, inclusive com o Mimir recém-restaurado. Com intervalo de
avaliação de 10 segundos e período de pendência de 30 segundos, dá para ver o
ciclo completo `Normal → Pending → Alerting` em menos de um minuto, ao vivo, na
lista de regras.

**Nomeie de forma honesta.** Sugestão:

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
