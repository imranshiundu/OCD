# ocdify.sh — the bootstrapper manual

`ocdify.sh` installs OCD's mechanical bar into any project in one command: a standalone verifier plus a Debt Ledger. It exists because discipline that isn't wired into the repo is discipline that evaporates.

It ships inside the skill folder, so an agent with OCD installed can run it against any project on the machine — no clone of this repo needed. Humans can clone and run it directly.

## Usage

```bash
bash ocd/scripts/ocdify.sh /path/to/project     # install verifier + ledger
bash ocd/scripts/ocdify.sh /path/to/project -f  # also replace an existing verifier copy
bash ocd/scripts/ocdify.sh /path/to/project -m  # also wire a make verify target
bash ocd/scripts/ocdify.sh /path/to/project -c  # check only — plan, touch nothing
bash ocd/scripts/ocdify.sh --version            # version from the skill frontmatter
```

## What it does

1. **Installs the verifier** — copies this skill's `verify.sh` to `<project>/scripts/verify.sh`. An existing copy is kept (pass `-f` to replace it).
2. **Bootstraps the ledger** — creates `<project>/DEBT_LEDGER.md` from the OCD template if missing.
3. **(with `-m`) wires the Makefile** — appends a `verify:` target; creates the Makefile if the project has none; never duplicates an existing target.
4. **Prints receipts** — what was installed, what was skipped and why, and the suggested wiring.

## Rules it never breaks

- **An existing `DEBT_LEDGER.md` is never overwritten — not even with `-f`.** The ledger is the owner's data; clobbering it would be destroying history.
- **An existing Makefile is only appended to**, and only when it lacks a `verify:` target.
- **Every action prints a receipt.** Every skip prints a reason. Nothing is silent.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | project is OCD-compliant (changes made, or already compliant) |
| `1` | usage error, target missing, or source verifier not found |
| `3` | `--check` only: the project needs work (nothing was touched) |

## --check: the CI-friendly mode

`--check` plans without touching. It prints `ok:` for what's present and `would install:` / `would create:` for what's missing, then exits `3` if the project needs work, `0` if compliant. Wire it into CI to demand ocdification without side effects:

```yaml
- name: Project must be OCD-compliant
  run: bash /path/to/ocd/scripts/ocdify.sh . -c
```

## After ocdifying

In the target project:

```bash
bash scripts/verify.sh .   # the mechanical bar, with receipts
make verify                # if you passed -m
```

The installed verifier is standalone: `--version` reports `standalone` rather than a skill version, and it won't automatically track skill releases. Re-run ocdify with `-f` to refresh it when the skill updates.

Commit both files. Every contributor — human and agent — inherits the bar.
