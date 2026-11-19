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
