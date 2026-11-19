# Debt Ledger

Known problems, ordered by severity. Burn items down proactively; never walk past a defect.

- [Medium] Social proof below the skill's own bar — the repo sits at 1 star and a handful of installs vs the "<100 stars gets skepticism" threshold it teaches. Action: owner-side; the bar explicitly exempts the discipline layer as an owner decision, but growing adoption is still the honest fix.
- [Low] pnpm/yarn/Maven/Gradle green paths are exercised in this environment only via their declared-skip fallbacks — the logic is symmetric with the tested npm/bun paths, but a machine with all four toolchains would give the first real green run. Action: run the selftest suite on a fully-loaded dev box or CI image.
- [Low] `just --summary` is treated as a complete recipe list; recipes defined only via submodules/imports may be missed. Action: acceptable for now, declared.
- [Low] The CI-workflow allowlist is deliberately narrow (canonical verification commands only); legitimate-but-nonstandard commands (e.g. `poetry run pytest`, `nx affected:test`) are skipped. Action: by design — widen only with fixtures proving each addition.
