SHELL := /bin/bash
.PHONY: help lint test verify install

help: ## show available targets
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "%-10s %s\n", $$1, $$2}'

lint: ## shellcheck every shipped script (bash -n fallback)
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck ocd/scripts/*.sh; \
	else echo "shellcheck not installed - bash -n syntax check only (declared skip)"; \
	for s in ocd/scripts/*.sh; do bash -n $$s || exit 1; done; fi

test: ## run the fixture selftest suite
	bash ocd/scripts/selftest.sh

verify: ## run the verifier against this repo
	bash ocd/scripts/verify.sh .

install: ## install the skill for AGENT=claude|opencode|agents
	@test -n "$(AGENT)" || { echo "usage: make install AGENT=claude|opencode|agents"; exit 1; }
	@case "$(AGENT)" in \
	claude) dest="$$HOME/.claude/skills/ocd" ;; \
	opencode) dest="$$HOME/.config/opencode/skills/ocd" ;; \
	agents) dest="$$HOME/.agents/skills/ocd" ;; \
	*) echo "unknown agent: $(AGENT) (use claude, opencode or agents)"; exit 1 ;; \
	esac; \
	mkdir -p "$$dest"; \
	cp -R ocd/. "$$dest/"; \
	echo "installed ocd -> $$dest"
