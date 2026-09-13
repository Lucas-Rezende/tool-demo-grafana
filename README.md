# Demo Grafana - Manutenção de Software (corretiva) em uma API real pequena

Esta pasta contem uma demo para apresentar a ferramenta Grafana.

Os dados utilizados não são sintéticos, eles são gerados pela API `orders-api`, que recebe requisições reais, grava eventos no PostgreSQL, e o Grafana mostra quando uma nova versão introduz um problema.

## Historia da demo

Um servico de pedidos funcionava normalmente na `v1`. Depois de um deploy para `v2`, usuários comecam a reclamar que o checkout ficou lento e falha algumas vezes. Em seguida, a equipe faz rollback para uma versão estável.

A pergunta que fica com isso é:

> Como o Grafana ajuda a equipe a sair de uma reclamação vaga para uma hipótese técnica de correção e validar que a manutenção funcionou?

## Arquitetura

Serviços:

- `postgres`: banco da demo.
- `orders-api-v1`: API sem bug, exposta em `http://localhost:8001`.
- `orders-api-v2`: mesma API, mas com bug no `/checkout`, exposta em `http://localhost:8002`.
- `loadgen`: simula usuários acessando catálogo, login, perfil e checkout.
- `grafana`: dashboard em `http://localhost:3000`.

## Onde esta o bug

Arquivo: `app/orders_api/main.py`.

Na `v2`, somente o endpoint `/checkout` fica mais lento e eventualmente retorna erro 500:

```text
database connection pool exhausted
```

Essa mensagem simula um bug comum depois de mudança em software: conexoes com banco sendo usadas de forma ineficiente, vazamento de conexão, pool mal dimensionado ou transação longa demais.

## Linha do tempo da demo

Cada fase dura 3 minutos:

- `0-3 min`: `v1` saudável.
- `3-6 min`: deploy da `v2`, com erro e latência no `/checkout`.
- `8-12 min`: rollback para uma versão estável.

Para a apresentação completa, deixe rodando cerca de **11 a 12 minutos**. Assim o Grafana terá dados suficientes para mostrar o problema e a recuperação.

## Como rodar

Na pasta da demo:

```bash
make demo
```

Esse comando sobe os containers, espera as APIs e o Grafana responderem, e tenta abrir o dashboard automaticamente no navegador.

Abra o Grafana, caso o navegador não abra automaticamente:

```text
http://localhost:3000/d/maintenance-demo/demo-grafana-manutencao?orgId=1&from=now-15m&to=now&timezone=browser&var-endpoint=$__all&var-version=$__all&refresh=10s
```

Login, se solicitado:

```text
usuario: admin
senha: admin
```

## Comandos uteis

```bash
make help    # lista comandos disponiveis
make demo    # sobe tudo e abre o dashboard
make verify  # verifica APIs e resumo do incidente
make logs    # acompanha logs do loadgen
make ps      # lista containers
make down    # para containers
make reset   # reinicia a demo do zero, apagando volumes
```