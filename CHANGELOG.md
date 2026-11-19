# Changelog

All notable changes to the OCD skill are documented here. The current version lives in the frontmatter (`metadata.version` in `ocd/SKILL.md`).

## [1.2.0] — 2026-11-20

### Added

- **The verifier ships inside the skill.** `scripts/` moved to `ocd/scripts/` — the skills CLI installs the whole skill folder (verified against its source: the skill folder's tree is what gets downloaded), so every `npx skills add imranshiundu/OCD@ocd` install now includes `verify.sh` next to SKILL.md. Previously installed users got text only; the verifier required a repo clone.
- **`ocdify` — one-command project bootstrap.** `ocd/scripts/ocdify.sh <project>` installs the verifier into `<project>/scripts/verify.sh` and bootstraps `DEBT_LEDGER.md` from the OCD template. Existing verifiers are kept unless `-f` is passed; existing ledgers are never overwritten, even with `-f` — the ledger is the owner's data. An agent with OCD installed can bootstrap any project on the machine.
- **verify.sh: the runner follows the project's lockfile.** `pnpm-lock.yaml` → `pnpm run`, `yarn.lock` → `yarn run`, `bun.lock`/`bun.lockb` → `bun run`; npm stays the default and the fallback when a lockfile's binary is missing — a declared fallback with a printed receipt, never silent. Script detection gains a `bun -e` tier for node-free machines.
- **verify.sh: JVM support.** `pom.xml` → `./mvnw -B test` (wrapper preferred, plain `mvn` fallback); `build.gradle`/`build.gradle.kts` → `./gradlew check`. Missing tooling prints a declared UNTESTED note — untestable is itself a finding.
- **verify.sh: CI-workflow safety net** (burns a Debt Ledger item). Single-line `run:` commands are extracted from `.github/workflows/` and only exact matches from a fixed allowlist of canonical verification commands are run — the same commands the project's own CI runs. Multiline blocks, pipes, variables, and anything else are skipped by design. Catches config-less projects whose only verification signal is a workflow.
- **verify.sh: duplicate commands run once.** A command detected through both project config and CI config runs a single time (`npm run lint`, `pnpm lint`, and `yarn run lint` normalize to one key), with a receipt for the skip.
- **GitHub Actions CI for this repo** — shellcheck on every shipped script, the full fixture selftest, and a self-verify pass on every push and pull request, with a README badge. The repo now passes its own bar in public.
- **selftest: 44 fixture assertions** (was 16) — bun runner, pnpm-absent fallback, maven/gradle declared-untestable, CI-workflow detection (allowed, rejected, deduped, multiline-ignored), and the full ocdify suite. The go fixture gains a real `main.go` so it holds on go-equipped machines.

### Fixed

- **Makefile uses real tabs and lints every shipped script** (glob, not a hard-coded list), with a declared `bash -n` fallback loop for machines without shellcheck.
- **selftest is shellcheck-clean** — the `A && B || C` assertion pattern (SC2015) rewritten as if/else.

### Burned from the Debt Ledger

- **[High] skills.sh indexing — resolved.** The skill is indexed and discoverable: `npx skills find ocd` lists `imranshiundu/ocd@ocd`, and the page is live at <https://www.skills.sh/imranshiundu/ocd>. skills.sh canonicalizes to lowercase; the GitHub repo name stays `OCD` — renaming is an owner's call with no functional gain (GitHub redirects cover it).
- **[Medium] verify.sh CI-config detection — shipped** in this release as the conservative workflow allowlist pass.

## [1.1.0] — 2026-10-10

### Fixed

- **The prescribed update command no longer stalls agents.** `npx skills update` (bare) prompts for a scope and hangs non-interactive shells until timeout — proven live (exit 124 at 30s). Every occurrence is now `npx skills update -y -g` (global) / `npx skills update -y` (project), with the flags documented as mandatory.
- **Session-start skill updates are throttled to once per 24h** (stamp file at `~/.cache/ocd/skills-update.stamp`), resolving the self-contradiction between "never bulk-bump dependencies" and an unthrottled bulk update at every session start. Skill updates remain the one sanctioned bulk operation, but every updated skill must be named in the arsenal report — a regression needs a named suspect.
- **"Restart the session after installing" rewritten as an owner-facing instruction** — an agent cannot restart its own session; it now tells the owner and verifies at the next session start.
- **One severity vocabulary everywhere.** Review findings and Debt Ledger entries both use `[Critical]/[High]/[Medium]/[Low]/[FYI]`; the old dual vocabulary (Critical/Consider/Nit vs Critical/High/Medium/Low) is gone.
- **TODO/FIXME ban now carves out owner-authored backlog markers** — never deleted, ledgered instead.
- **"Suggest better and cool ideas" reworded** — discipline documents don't get to be sloppy.

### Added

- **Precedence rules for when the Three Laws collide** (owner instruction > reversibility > clean revert) — previously two laws could both apply with no tiebreaker, e.g. "set up minimum lint+tests" vs "propose toolchain changes first". The Zero-Error tooling clause now distinguishes code-you're-touching (set up) from repos that deliberately ship without tooling (propose).
- **The Debt Ledger has a home: `DEBT_LEDGER.md` at the repo root.** Previously the skill demanded a "running list" with no defined location — non-functional across stateless sessions.
- **`scripts/verify.sh` — the Zero-Error Exit Criteria, mechanically enforced.** Detects lint/typecheck/test/build from package.json, Makefile, justfile, Cargo.toml, go.mod, and pyproject configs; runs each; prints receipts (command + exit code + verbatim output tail). Exit 0 green, 1 red, 2 untestable — and untestable is itself a finding.
- **`scripts/selftest.sh` — fixture-based tests for verify.sh itself** (green/red npm projects, Makefile, justfile, cargo, go fixtures, alias detection, help text).
- **`Makefile`** — `make lint` (shellcheck, fallback `bash -n`), `make test` (selftest), `make verify` — so this repo passes its own verifier.
- **SKILL.md ships a minimal inline verification loop** — a self-contained fallback for when only the skill (not the repo scripts) is installed; `scripts/verify.sh` remains canonical.
- **Install procedure now documents the CLI-vs-manual trade-off**: manual copies register as `Source: local`, are invisible to `npx skills update`, and don't count toward skills.sh install metrics.
- **Skill-sourcing thresholds clarified**: below the bar means harder verification, not automatic rejection; and the bar applies to domain skills — the discipline layer itself is an explicit owner decision.
- **Session-start skill loading is capped at three relevant skills, declared** — "read all the skills" was context arson.
- **Frontmatter: `license: MIT`, `metadata.version`** — versioning is now machine-readable (skills CLI parsing of the nested block verified).
- **OCD-version-triggered arsenal update:** when the skill's own `metadata.version` changes (stamp: `~/.cache/ocd/version`), the next session re-syncs the installed-skill arsenal regardless of the 24h throttle. A skill is text, not a daemon — the automation is the agent following this instruction at session start.
- **See Also now covers plan stress-testing:** `mattpocock/skills@grill-me` (1.3M installs) — a dispatcher skill whose payload is `mattpocock/skills@grilling`; both are required or the stub points at a missing dependency.

## [1.0.0] — 2026-09-19

- Initial release: Three Laws, Session Start arsenal, install procedure, Zero-Error Exit Criteria, Truth/Receipts protocols, No-Laziness Protocol, Six-Axis Sweep, Smell Baseline, Code Judo, Severity Labels, Scale Protocol, Debt Ledger, Dependency Discipline, Rationalizations, Red Flags, Final Report.
