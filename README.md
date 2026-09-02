# Tool Demo — Grafana

Trabalho prático da disciplina **Manutenção e Evolução de Software** (DCC/UFMG).
Vale 10 pontos. Consiste em demonstrar ao vivo, em 15 minutos, uma ferramenta de
apoio à manutenção de software.

**Ferramenta escolhida:** [Grafana](https://grafana.com/oss/grafana/), na
categoria *observabilidade*.

**Grupo (3 pessoas):**

| | Nome | Bloco na apresentação | Perguntas que responde |
|---|---|---|---|
| 1 | `PREENCHER` | 0:00–5:00 — visão geral e dashboard | arquitetura, data sources |
| 2 | `PREENCHER` | 5:00–10:30 — logs e traces | Loki, Tempo, instrumentação |
| 3 | `PREENCHER` | 10:30–15:00 — alertas e conclusão | alertas, operação, limitações |

## A demo em três comandos

```bash
make setup     # uma vez por máquina: clona o stack, corrige a retenção, baixa imagens
make record    # sobe o stack e abre a janela de gravação (deixe rodar ~45 min)
make freeze    # para tudo e congela os volumes em snapshot/
```

No dia da apresentação, só isto:

```bash
make restore   # recria os volumes a partir de snapshot/ e sobe o stack (2 a 3 min)
make verify    # semáforo de OK/FALHOU por fonte de dados
```

`make` sem argumento lista todos os alvos.

> **O Git for Windows não traz `make`.** Se `make: command not found` aparecer,
> chame os scripts direto — o comportamento é idêntico, porque cada alvo do
> Makefile é só um envelope:
>
> ```bash
> ./stack/setup.sh
> ./stack/record.sh          # ./stack/record.sh --do-zero para gravar do zero
> ./stack/freeze.sh
> ./stack/restore.sh
> ./stack/verify.sh
> ```
>
> Para instalar o `make` no Windows: `winget install GnuWin32.Make` ou
> `choco install make`.

## Pré-requisitos

| Item | Mínimo | Observação |
|---|---|---|
| Docker Engine | 24+ | Docker Desktop no Windows e no macOS |
| Docker Compose | v2 | o plugin `docker compose`; o `docker-compose` v1 não serve |
| Git | qualquer versão recente | usado por `make setup` para clonar o stack |
| `make` | opcional | não vem com o Git for Windows; sem ele, chame os scripts direto |
| RAM livre | 6 a 8 GB | são 12 containers; abaixo de 6 GB o Tempo começa a matar consulta |
| Disco livre | ~10 GB | imagens (~4 GB) mais a janela congelada |
| Shell | Bash | no Windows, use o **Git Bash**, não o PowerShell |
| Portas livres | 3000, 3001, 3100, 3200, 9009, 5432, 5672, 15672, 4317, 4318 | ver `docs/07-plano-de-contingencia.md` se alguma estiver ocupada |

> **`snapshot/` não vai para o Git.** São centenas de megabytes de blocos de
> TSDB, chunks de log e blocos de trace. A pasta está no `.gitignore`. Combine
> com o grupo como compartilhar o dataset congelado: pendrive, Drive ou zip.
> Sem `snapshot/`, o `make restore` não tem o que restaurar — mas `make record`
> gera um novo dataset do zero em ~45 minutos.

## Índice comentado

| Documento | Para quê |
|---|---|
| [`docs/01-visao-geral-grafana.md`](docs/01-visao-geral-grafana.md) | O que é o Grafana, arquitetura em três peças, histórico e novidades da versão 13. Base do bloco de abertura. |
| [`docs/02-grafana-e-manutencao-de-software.md`](docs/02-grafana-e-manutencao-de-software.md) | A ligação com a disciplina: manutenção corretiva, perfectiva e evolução. É o eixo do trabalho. |
| [`docs/03-escopo-e-fronteiras.md`](docs/03-escopo-e-fronteiras.md) | **Leia antes de ensaiar.** Onde a nossa demonstração para e a de outro grupo começa, com checklist operacional. |
| [`docs/04-demo-reprodutivel.md`](docs/04-demo-reprodutivel.md) | O documento mais importante. Como congelar o dataset e rodar a demo em 3 minutos, com as armadilhas do repositório oficial. |
| [`docs/05-roteiro-apresentacao.md`](docs/05-roteiro-apresentacao.md) | Minuto a minuto dos 15 minutos, com as falas de transição e a divisão de perguntas. |
| [`docs/06-pontos-fortes-e-fracos.md`](docs/06-pontos-fortes-e-fracos.md) | Os slides de conclusão. A parte de pontos fracos é escrita sem amenizar. |
| [`docs/07-plano-de-contingencia.md`](docs/07-plano-de-contingencia.md) | O que fazer quando algo quebra na frente da turma. |
| [`stack/JANELA.md`](stack/JANELA.md) | Folha de cola do dia: epochs da janela e os favoritos na ordem do roteiro. |

## O que tem em `stack/`

Automação da demo. Nenhum código do Grafana mora aqui: o stack demonstrado é o
[`grafana/intro-to-mltp`](https://github.com/grafana/intro-to-mltp) oficial, que
`make setup` clona em `intro-to-mltp/` (fora do Git) e fixa em um commit
conhecido.

| Arquivo | O que faz |
|---|---|
| `_comum.sh` | Variáveis e funções compartilhadas. Não é executado direto. |
| `docker-compose.override.yml` | Cria os volumes nomeados que faltam, tira o Grafana da internet, tema claro. |
| `setup.sh` | Clona e fixa o stack, corrige a retenção do Tempo, baixa as imagens. |
| `record.sh` | Sobe o stack sem k6 e abre a janela de gravação. |
| `freeze.sh` | Para os containers e exporta os volumes para `snapshot/*.tgz`. |
| `restore.sh` | Recria os volumes a partir dos tarballs e sobe o stack. Idempotente. |
| `verify.sh` | Semáforo de OK/FALHOU por fonte de dados dentro da janela. |
| `urls.sh` | Gera as sete URLs congeladas e `snapshot/favoritos.html`, importável no navegador. |
| `pin-images.sh` | Imprime as imagens `mythical-*` fixadas por digest. |
| `clean.sh` | Derruba o stack e apaga os volumes. Preserva `snapshot/`. |

## Licença

MIT, para o material próprio deste repositório. Ver [`LICENSE`](LICENSE).
