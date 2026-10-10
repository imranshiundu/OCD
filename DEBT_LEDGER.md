# Debt Ledger

Known problems, ordered by severity. Burn items down proactively; never walk past a defect.

- [High] skills.sh does not index this skill — page 404s under both `imranshiundu/OCD/ocd` and `imranshiundu/ocd/ocd`, and it never appears in `npx skills find` results, so the skill fails its own sourcing bar (no discoverable install count). Action: verify indexing after 1.1.0 is pushed and CLI installs begin registering; align repo casing with whatever skills.sh canonicalizes.
- [Medium] Social proof below the skill's own bar — repo sits at 1 star vs the "<100 stars gets skepticism" threshold it teaches. Action: owner-side; the bar now explicitly exempts the discipline layer as an owner decision, but growing adoption is still the honest fix.
- [Medium] verify.sh's CI-config detection is absent — GitHub Actions workflows are a declared gap (parsing arbitrary CI YAML is fragile; package.json/Makefile/justfile/Cargo/go/pytest cover the common cases). Action: add a conservative `.github/workflows` grep pass if real projects need it.
- [Low] `just --summary` is treated as a complete recipe list; recipes defined only via submodules/imports may be missed. Action: acceptable for now, declared.
