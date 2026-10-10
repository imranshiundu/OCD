# Changelog

All notable changes to the OCD skill are documented here. The current version lives in the frontmatter (`metadata.version` in `ocd/SKILL.md`).

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
