# Roteiro de explicacao para a apresentacao

Este roteiro segue a ideia do slide "Seis perguntas, seis recursos do Grafana".

## 1. Detectar: algo mudou?

Mostre os painéis de taxa de erro 5xx, latencia P95 e semáforo.

Fala sugerida:

> Primeiro eu quero saber se o comportamento do sistema mudou. O Grafana mostra que erro e latencia subiram. Isso transforma uma reclamação vaga em evidência observável.

## 2. Relacionar: com qual mudanca?

Mostre a anotação de deploy da v2.

Fala sugerida:

> A anotacao de deploy marca quando a versao v2 entrou. Isso nao prova a causa sozinho, mas indica que a regressao comecou junto com uma mudanca de software.

## 3. Reduzir escopo: e o sistema todo?

Mostre os filtros `version` e `endpoint`.

Fala sugerida:

> Com variaveis do dashboard, eu filtro por versao e endpoint. Assim eu nao preciso olhar todos os dados misturados. Eu separo o comportamento da v2 e foco no checkout.

## 4. Priorizar: onde doi mais?

Mostre `Erros 5xx por endpoint` e `Resumo por versao e endpoint`.

Fala sugerida:

> O problema se concentra no checkout. Como checkout e um fluxo critico em um servico de pedidos, isso vira prioridade de manutencao.

## 5. Hipotese: por que?

Mostre a tabela `Registros de erro para investigacao`.

Fala sugerida:

> A mensagem `database connection pool exhausted` sugere uma hipotese tecnica: a v2 pode ter introduzido um problema no uso de conexoes com banco. O Grafana nao corrige o bug, mas encurta o caminho ate uma hipotese investigavel.

## 6. Acompanhar: a correcao funcionou?

Mostre que os mesmos paineis serviriam depois de rollback ou correcao.

Fala sugerida:

> Depois de corrigir ou fazer rollback, a equipe usa os mesmos paineis para confirmar se erro e latencia voltaram ao normal. Isso fecha o ciclo de manutencao.

## Frase de fechamento

> Grafana nao encontra o bug sozinho; ele transforma sintomas de producao em evidencias para orientar a manutencao.