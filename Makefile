# Top-level Makefile for myMisterTemplate
#
# Provides convenience targets for working with the Quartus container
# wrapper that lives in scripts/quartus.

PROJECT ?= mycore
QUARTUS_DEV_CMD ?= quartus_sh --flow compile $(PROJECT)

.PHONY: quartus-dev
quartus-dev:
	./scripts/quartus $(QUARTUS_DEV_CMD)

