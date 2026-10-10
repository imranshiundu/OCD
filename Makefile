.PHONY: lint test verify

lint:
	if command -v shellcheck >/dev/null 2>&1; then shellcheck scripts/verify.sh scripts/selftest.sh; else bash -n scripts/verify.sh && bash -n scripts/selftest.sh; fi

test:
	bash scripts/selftest.sh

verify:
	bash scripts/verify.sh .
