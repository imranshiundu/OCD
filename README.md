# OCD — Obsessive Code Discipline

[![CI](https://github.com/imranshiundu/OCD/actions/workflows/ci.yml/badge.svg)](https://github.com/imranshiundu/OCD/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![skills.sh](https://img.shields.io/badge/skills.sh-imranshiundu%2Focd-blue)](https://www.skills.sh/imranshiundu/ocd)
[![Stars](https://img.shields.io/github/stars/imranshiundu/OCD.svg)](https://github.com/imranshiundu/OCD/stargazers)

**A zero-tolerance discipline for coding agents — and the toolkit that enforces it.**

OCD keeps agents honest and code actually working: verification before "done", hard truths over flattery, proactive fixes over silent waiting, and a debt ledger that gets burned down instead of buried. It installs as a single skill and works with any agent that reads `SKILL.md` — opencode, Claude Code, and friends.

- **Zero dependencies, zero telemetry** — one skill file, three portable bash scripts (bash 3.2 compatible, macOS-safe)
- **Any scale** — from a 50-line script to an enterprise monolith: the bar never drops, only the ceremony adapts
- **Mechanically enforced** — the verifier reads your project's own config and runs its own lint/typecheck/test/build before anyone claims "done"

## Table of contents

- [The problem](#the-problem)
- [The Three Laws](#the-three-laws)
- [Install](#install)
- [Quick start](#quick-start)
- [The toolkit](#the-toolkit)
- [What verify.sh detects](#what-verifysh-detects)
- [Self-verification](#self-verification)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Versioning](#versioning)
- [Community](#community)
- [Acknowledgements](#acknowledgements)

## The problem

Coding agents have three common failure modes:

1. **They flatter.** "Great idea!" — then implement it badly, silently, and say nothing.
2. **They leave things broken.** Red tests plus the words "done". Waved-away warnings. Code that compiles but doesn't work.
3. **They wait to be asked.** They see the bug and stay silent until the owner trips over it.

OCD replaces all three with discipline, and — more importantly — with structure that makes the failure modes hard: receipts for every claim, a verifier that decides "done", and a ledger that remembers what still hurts.

## The Three Laws

1. **The code must be clean and actually working.** No errors, no waved warnings, no "it should work". Proof or it doesn't count.
2. **The truth must be told.** No sycophancy, no lying, no softening. If something is wrong, the agent says so — without being asked. The truth hurts once; flattery compounds the losses.
3. **Fix without being asked.** Obvious defects get fixed or flagged in the same breath they were seen.

The skill text covers what sits underneath: the [Receipts Protocol](#) (evidence blocks, VERIFIED / ASSUMED / UNKNOWN labels), the No-Laziness Protocol, the Six-Axis Sweep, the smell baseline, code judo, severity labels, and the scale protocol. See [`ocd/SKILL.md`](ocd/SKILL.md) for the full standard.

## Install

### Skills CLI (recommended)

```bash
npx skills add imranshiundu/OCD@ocd -g -y
```

CLI installs are tracked: `npx skills update -y -g` upgrades them later, and installs count toward the [skills.sh](https://www.skills.sh/imranshiundu/ocd) metrics. The toolkit scripts (`verify.sh`, `ocdify.sh`, `ledger.sh`) ship inside the skill folder, so the install includes the machinery, not just the text.

### Manual install

```bash
git clone https://github.com/imranshiundu/OCD.git
make install AGENT=claude    # or: AGENT=opencode | AGENT=agents
```

Or copy the `ocd/` folder into your agent's skill directory:

| Agent | Global path | Project path |
|---|---|---|
| opencode | `~/.config/opencode/skills/ocd/` | `.opencode/skills/ocd/` |
| Claude Code | `~/.claude/skills/ocd/` | `.claude/skills/ocd/` |
| Any `.agents` reader | `~/.agents/skills/ocd/` | `.agents/skills/ocd/` |

Manual copies are frozen — they register as `Source: local`, the updater never touches them, and they don't count toward install metrics. If you go manual, you own re-syncing by hand, or symlink from a local clone (the dev pattern).

Then restart your agent session so the skill loads.

## Quick start

**If you are an agent** — the skill triggers automatically in any codebase. Invoke it directly with:

- "Run an OCD pass on this project"
- "OCD check before we ship"
- "Be OCD about this"

You'll get the worst thing first, a full verification loop with receipts, and an updated Debt Ledger.

**If you are a human** — bootstrap the mechanical bar into any repo, no skill install needed:

```bash
git clone https://github.com/imranshiundu/OCD.git
OCD/ocd/scripts/ocdify.sh /path/to/your/project        # verifier + ledger
OCD/ocd/scripts/ocdify.sh /path/to/your/project -m     # ...and a make verify target
```

Then, in your project:

```bash
bash scripts/verify.sh .     # lint/typecheck/test/build, with receipts
```

## The toolkit

Three scripts ship inside the skill folder. Full manuals in [`docs/`](docs/).

### verify.sh — the mechanical bar

Detects the verification commands from a project's **own** config, runs each one, and prints receipts: the command, its exit code, and the verbatim output tail. A red suite plus the word "done" is a lie — this makes the lie impossible to print with a straight face.

```bash
bash ocd/scripts/verify.sh .            # human-readable receipts
bash ocd/scripts/verify.sh --json .     # one JSON document, for tooling
bash ocd/scripts/verify.sh --version    # version, read from the skill frontmatter
```

| Exit code | Meaning |
|---|---|
| `0` | all detected commands green |
| `1` | at least one command failed — fix and re-run |
| `2` | no verification commands detected (untestable — itself a finding) |
| `64` | usage error |

### ocdify.sh — bootstrap any project

One command installs the mechanical bar into any repo:

```bash
bash ocd/scripts/ocdify.sh /path/to/project     # verifier + Debt Ledger
bash ocd/scripts/ocdify.sh /path/to/project -f  # also replace an existing verifier copy
bash ocd/scripts/ocdify.sh /path/to/project -m  # also wire a make verify target
bash ocd/scripts/ocdify.sh /path/to/project -c  # check only — plan, touch nothing
```

An existing `DEBT_LEDGER.md` is never overwritten, even with `-f` — the ledger is the owner's data. `--check` exits `3` when the project needs work and `0` when it is already compliant, so CI can demand ocdification without side effects.

### ledger.sh — keep the ledger honest

The Debt Ledger is a file, not a metaphor: `DEBT_LEDGER.md` at the repo root, ordered by severity. This script maintains it mechanically:

```bash
bash ocd/scripts/ledger.sh add "[High] checkout flow has no tests"
bash ocd/scripts/ledger.sh ls
bash ocd/scripts/ledger.sh burn 2          # fixed — moves to the dated Burned section
bash ocd/scripts/ledger.sh validate
```

Burned items are struck through and dated, never deleted — history remembers what was fixed and when.

## What verify.sh detects

The verifier reads the project's own configuration. It never guesses a toolchain that isn't there, and a missing tool is a declared `UNTESTED` note — never silent.

| Signal in the project | What runs |
|---|---|
| `package.json` + `package-lock.json` / no lockfile | `npm run lint/typecheck/test/build` |
| `package.json` + `pnpm-lock.yaml` | `pnpm run …` |
| `package.json` + `yarn.lock` | `yarn run …` |
| `package.json` + `bun.lock` / `bun.lockb` | `bun run …` |
| `Makefile` | `make lint/typecheck/test/build` (targets that exist) |
| `justfile` | `just lint/typecheck/test/build` (recipes that exist) |
| `Cargo.toml` | `cargo fmt --check` (when rustfmt present), `cargo test` |
| `go.mod` | `go vet ./…`, `go test ./…`, `go build ./…` |
| `pom.xml` | `./mvnw -B test` (wrapper preferred, `mvn` fallback) |
| `build.gradle` / `build.gradle.kts` | `./gradlew check` (wrapper preferred, `gradle` fallback) |
| `composer.json` | `composer run test` (when `scripts.test` is defined) |
| `deno.json` / `deno.jsonc` | `deno lint`, `deno test` |
| `CMakeLists.txt` | `cmake -S . -B <tmp> && cmake --build <tmp>` (temp dir, tree untouched) |
| `pyproject.toml` / `setup.py` + pytest | `poetry run pytest -q` when `poetry.lock` + poetry exist, else `python3 -m pytest -q` |
| `pyproject.toml` + ruff config | `ruff check .` |
| `.github/workflows/*.yml` | see below |

**CI-workflow detection.** Single-line `run:` commands are extracted from GitHub workflow files, and only exact matches from a fixed allowlist of canonical verification commands (`npm run test`, `pytest`, `make lint`, `go test ./...`, …) are run. Multiline blocks, pipes, variables, and anything not on the list are skipped by design — the verifier runs what the project's own CI runs, nothing more. Commands detected twice (config *and* workflow) run once, with a receipt for the skip.

## Self-verification

This repo passes its own bar, in public, on every push — [CI](https://github.com/imranshiundu/OCD/actions/workflows/ci.yml) runs shellcheck, the full fixture selftest, and a self-verify pass on both ubuntu and macOS.

```bash
make help   # list targets
make lint   # shellcheck every shipped script (bash -n fallback)
make test   # fixture selftest: green and red projects, every detector, every flag
make verify # run the verifier against this repo
```

The selftest proves the verifier with real fixture projects — green and red suites for every supported toolchain, package-manager detection, CI-workflow allowlisting, JSON mode, the bootstrapper, and the ledger manager. Fixtures that need absent tools skip with a declaration, exactly as the skill prescribes.

## FAQ

**Does it work with my agent?**
If your agent loads skills from `~/.claude/skills/`, `~/.config/opencode/skills/`, or `~/.agents/skills/` — yes. That covers opencode, Claude Code, and every `.agents`-convention reader. The toolkit scripts also work standalone with no agent at all.

**Is it free? Where's the catch?**
MIT licensed, no telemetry, no network calls, no dependencies. The "catch" is that it holds your agent to a bar that takes longer to pass.

**Why does skills.sh show lowercase `imranshiundu/ocd`?**
skills.sh canonicalizes repo names to lowercase; GitHub is case-insensitive for redirects. Same skill, same install command either way.

**Can I use verify.sh without installing the skill?**
Yes — `ocdify.sh` copies a standalone verifier into any project. It reports `standalone` via `--version` and won't track skill versions until you re-ocdify (`-f`).

**Does it run on Windows?**
The scripts are bash. Use WSL, Git Bash, or MSYS. Native PowerShell is not supported (yet — see the Debt Ledger).

**What if my project has no lint/tests at all?**
The verifier exits `2` — untestable — and says so loudly. That exit code is itself the finding: per the skill, the minimum tooling (lint + tests) is part of any change that touches code.

**How does an agent know when to use this?**
The skill's frontmatter description triggers it at session start, before claiming any work done, and on any mention of code quality, verification, honesty, receipts, or debt. The invocation phrases are in the skill text.

## Troubleshooting

**The skill didn't load after install.** Skills load at session start; restart the agent session. `make install AGENT=claude` prints where it landed — verify `SKILL.md` exists there.

**`verify.sh` exits 2 on my repo.** No verification commands were detected: no package.json scripts, no Makefile/justfile targets, none of the supported config files, no allowlisted workflow commands. Add the minimum (a lint script and a test) — or ledger the gap deliberately.

**"falling back to npm (declared)" on my pnpm project.** Your lockfile says pnpm but the `pnpm` binary isn't on the machine's PATH. Install pnpm (`npm i -g pnpm`) and re-run — the fallback is a declared compromise, not a silent switch.

**The CI-workflow pass ran nothing.** By design: only exact, allowlisted, single-line `run:` commands run. Multiline blocks, pipes, and variables are ignored. If your canonical command is missing from the allowlist, open an issue — widening it requires a fixture that proves the addition.

**JSON mode contains an escaped mess in `tail`.** The tail is verbatim output, JSON-escaped. Exotic control characters beyond quotes, backslashes, and newlines are not fully escaped — if that bites you, open an issue with the output that broke parsing.

## Development

```bash
git clone https://github.com/imranshiundu/OCD.git
cd OCD
make lint && make test && make verify   # the same bar CI enforces
```

Layout:

```
ocd/SKILL.md            the skill itself — the standard, in agent-readable form
ocd/scripts/verify.sh   the mechanical bar (Zero-Error Exit Criteria)
ocd/scripts/ocdify.sh   project bootstrapper
ocd/scripts/ledger.sh   debt ledger maintenance
ocd/scripts/selftest.sh fixture suite proving all of the above
docs/                   per-script manuals
```

Adding a detector? The checklist: a fixture in `selftest.sh` (green + declared-untestable when the tool is absent), the row in the detection matrix above, a line in `docs/VERIFY.md`, and a changelog entry. A detector without fixtures is a claim without receipts — it doesn't merge.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow, commit style, and the release process.

## Versioning

Semantic versioning; the current version lives in the frontmatter (`metadata.version` in `ocd/SKILL.md`) and in every script's `--version` output. History is in [CHANGELOG.md](CHANGELOG.md); known open problems are tracked honestly in [DEBT_LEDGER.md](DEBT_LEDGER.md). Pushing a `v*` tag publishes a GitHub release automatically, with the matching changelog section as the body.

A skill is text, not a daemon: when the version changes, agents re-sync their installed arsenal on the next session (the skill text prescribes it).

## Community

- [Contributing](CONTRIBUTING.md) — development setup, detector checklist, commit style, releases
- [Security policy](SECURITY.md) — reporting, scope, supply-chain posture
- [Code of conduct](CODE_OF_CONDUCT.md) — the standard for behavior here
- [Issues](https://github.com/imranshiundu/OCD/issues) — bugs, detector requests, allowlist proposals

## Acknowledgements

OCD distills and upgrades patterns from excellent opensource work:

- [mattpocock/skills](https://github.com/mattpocock/skills) — the Fowler smell baseline and standards-vs-spec review axes
- [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) — the multi-axis review, severity labels, honesty and dependency discipline
- [cursor/plugins](https://github.com/cursor/plugins) — the thermo-nuclear code-judo ambition and structural blocking

## License

MIT — see [LICENSE](LICENSE).
