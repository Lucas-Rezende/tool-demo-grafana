# 07 — Plano de contingência

O que fazer quando algo quebra na frente da turma. Leia antes de apresentar;
no momento do problema não dá tempo.

Regra geral: **nunca depurar ao vivo.** Cair para o plano B leva 10 segundos e
custa muito menos que dois minutos de silêncio com alguém digitando comando.

## Antes de sair de casa

- [ ] `make restore` e `make verify` rodados na máquina que vai apresentar,
      com tudo verde.
- [ ] Os 7 favoritos abrem com dados, sem tocar no seletor de tempo.
- [ ] Vídeo de backup gravado (ver abaixo).
- [ ] `snapshot/` copiado para um pendrive.
- [ ] Slides exportados em PDF, em um pendrive e em um e-mail para os três.
- [ ] Segunda máquina com o ciclo completo já testado. Se só uma máquina do
      grupo roda a demo, o trabalho tem um ponto único de falha.

## O vídeo de backup

Grave a demonstração inteira em vídeo durante o ensaio geral, com narração ou
sem. De 6 a 8 minutos, cobrindo os blocos 1 e 2 e a parte de alertas do bloco 3.

O vídeo não substitui a demonstração — o enunciado exige demonstração real, e
screenshot não basta. Ele é seguro contra o caso em que o Docker não sobe na
sala de aula. Se for preciso usar, diga em voz alta que é uma gravação do
ensaio e por que está sendo usada.

Guarde em dois lugares: no disco da máquina e em um pendrive.

## Problemas e respostas

### O Docker não sobe

**Sintoma:** `make restore` falha logo no início, com erro de daemon.

**Resposta:** tentar na segunda máquina do grupo. Se falhar também, vídeo de
backup.

### Uma porta está ocupada

**Sintoma:** `port is already allocated` durante o `up`.

O stack usa 3000, 3001, 3100, 3200, 9009, 5432, 5672, 15672, 4317, 4318, 80 e
mais algumas. A colisão mais comum é 3000 (outro projeto Node) e 5432
(Postgres local).

**Resposta imediata:** derrube o processo concorrente.

```bash
docker ps                          # é outro container?
netstat -ano | findstr :3000       # Windows: descobre o PID
```

**Se não der:** vídeo de backup. Mudar porta ao vivo obriga a refazer todos os
favoritos.

### O Grafana sobe mas os painéis estão vazios

**Causa quase certa:** o intervalo de tempo saiu da janela congelada. Alguém
clicou em "Last 6 hours" ou recarregou um link sem `from`/`to`.

**Resposta:** clicar no favorito de novo. Todos os favoritos carregam o
intervalo absoluto. Não mexa no seletor.

### O trace não abre / a cascata de spans está vazia

**Causa quase certa:** a retenção do Tempo voltou para `1h`. Isso acontece se
alguém rodou `git checkout` ou `git pull` dentro de `intro-to-mltp/` depois do
`make setup`, revertendo o `tempo.yaml`.

**Resposta ao vivo:** usar o favorito 5 (trace aberto direto). Se ele também
falhar, seguir para o vídeo, explicando que houve um problema de retenção de
dados — o que, aliás, é um comentário legítimo sobre operação de sistemas de
observabilidade.

**Resposta depois:**

```bash
make setup       # recoloca 336h e confere
make record-zero # regrava a janela
make freeze
```

### O k6 subiu sem querer

**Sintoma:** `make verify` acusa `[FALHOU] k6 FORA do ar`.

**Causa:** alguém rodou `docker compose up` na mão, sem `--scale k6=0`. O
serviço tem `restart: always` e volta sozinho.

**Resposta:**

```bash
make restore     # sobe tudo de novo, corretamente
```

Se precisar resolver sem derrubar o resto:

```bash
docker compose -f intro-to-mltp/docker-compose.yml \
               -f stack/docker-compose.override.yml \
               rm -sf k6
```

### A regra de alerta realista aparece em No Data

**Isso é esperado**, não é falha. Está explicado em
[`04-demo-reprodutivel.md`](04-demo-reprodutivel.md), seção de alertas, e a
fala da pessoa 3 já cobre. A regra sintética é que mostra a transição ao vivo.

### O dashboard copiado sumiu

**Causa:** o volume `grafana` foi recriado sem restaurar o tarball, ou alguém
rodou `make clean` e depois `make record` em vez de `make restore`.

**Resposta ao vivo:** usar o `MLT Dashboard` original (provisionado, sempre
presente) com o intervalo absoluto colado à mão na URL. Perde-se o ajuste da
cópia, não a demonstração.

### A internet da sala não funciona

**Não é problema.** Tudo roda em `localhost` e o override desliga as chamadas
externas do Grafana (feed de notícias, checagem de atualização, telemetria). Os
plugins já vieram congelados dentro de `snapshot/grafana.tgz`.

O único requisito de rede é ter rodado `make setup` antes, em casa.

### O projetor corta a lateral da tela

**Resposta:** `Ctrl -` no navegador para reduzir o zoom, e recolher o menu
lateral do Grafana (ícone de hambúrguer). O tema claro já está configurado por
padrão no override, que projeta melhor que o escuro.

Teste isto no ensaio, com o projetor real se possível.

### Alguém pergunta sobre profiling ou Pyroscope

**Resposta:** está fora do nosso escopo por ser o tema do grupo de profilers.
Devolver para a fala de amarração do bloco 3 (o Grafana estreita o problema até
o span; o profiler entra a partir dali). Não abrir o Pyroscope para
"mostrar rapidinho".

## Ordem de decisão, no momento do aperto

1. Clicar no favorito de novo. Resolve a maioria dos casos.
2. Pular para o próximo passo do roteiro e voltar depois, se der.
3. Trocar de máquina, se a segunda estiver com o stack no ar.
4. Vídeo de backup, dizendo em voz alta que é uma gravação do ensaio.

Nunca: abrir terminal e depurar com a turma esperando.
