SHELL := /bin/bash
.PHONY: lint test verify

lint:
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck ocd/scripts/*.sh; \
	else echo "shellcheck not installed - bash -n syntax check only (declared skip)"; \
	for s in ocd/scripts/*.sh; do bash -n $$s || exit 1; done; fi

test:
	bash ocd/scripts/selftest.sh

verify:
	bash ocd/scripts/verify.sh .
