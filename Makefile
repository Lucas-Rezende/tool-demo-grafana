# Atalhos para os scripts de stack/. Cada alvo é um envelope fino: a lógica
# toda mora nos scripts, para que quem preferir rodar `./stack/x.sh` na mão
# tenha exatamente o mesmo comportamento.
#
# No Windows, rode pelo Git Bash. Se não tiver `make`, chame os scripts direto.

SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help setup record record-zero freeze restore verify urls pin clean

help:
	@echo ""
	@echo "  Tool Demo — Grafana — DCC/UFMG"
	@echo ""
	@echo "  Fluxo normal, uma vez só:"
	@echo "    make setup     Clona o intro-to-mltp, corrige a retenção do Tempo e baixa as imagens"
	@echo "    make record    Sobe o stack sem k6 e abre a janela de gravação (~45 min)"
	@echo "    make freeze    Para os containers e exporta os volumes para snapshot/"
	@echo ""
	@echo "  Fluxo do dia da apresentação:"
	@echo "    make restore   Recria os volumes a partir de snapshot/ e sobe o stack"
	@echo "    make verify    Semáforo de OK/FALHOU por fonte de dados na janela congelada"
	@echo ""
	@echo "  Auxiliares:"
	@echo "    make record-zero  Como 'record', mas apaga os volumes antes"
	@echo "    make urls         Gera as URLs congeladas e snapshot/favoritos.html"
	@echo "    make pin          Imprime as imagens mythical-* fixadas por digest"
	@echo "    make clean        Derruba o stack e apaga os volumes (snapshot/ é preservado)"
	@echo ""

setup:
	@./stack/setup.sh

record:
	@./stack/record.sh

record-zero:
	@./stack/record.sh --do-zero

freeze:
	@./stack/freeze.sh

restore:
	@./stack/restore.sh

# Use `make verify` para ler a janela de snapshot/janela.env, ou
# `make verify INICIO=1756... FIM=1756...` para informar uma janela na mão.
verify:
	@./stack/verify.sh $(INICIO) $(FIM)

urls:
	@./stack/urls.sh

pin:
	@./stack/pin-images.sh

clean:
	@./stack/clean.sh
