# verify.sh — the verifier manual

`verify.sh` is the mechanical form of the OCD Zero-Error Exit Criteria: it detects the verification commands from a project's own configuration, runs each one, and prints receipts — the command, its exit code, and the verbatim tail of its output. A red suite plus the word "done" is a lie; this script makes the lie hard to print.

It is plain bash (3.2 compatible — it runs on the bash macOS ships), needs nothing but the tools your project already uses, and makes zero network calls.

## Usage

```bash
bash ocd/scripts/verify.sh                     # current directory
bash ocd/scripts/verify.sh /path/to/project    # another project
bash ocd/scripts/verify.sh --json .            # machine-readable receipts
bash ocd/scripts/verify.sh --version           # version from the skill frontmatter
bash ocd/scripts/verify.sh -h                  # help
OCD_TAIL_LINES=40 bash ocd/scripts/verify.sh . # longer verbatim receipts
```

## Exit codes

| Code | Meaning |
|---|---|
| `0` | all detected commands green |
| `1` | at least one command failed — fix and re-run |
| `2` | no verification commands detected (untestable — itself a finding) |
| `64` | usage error (unknown flag, extra path) |

Exit `2` is not an error state to hide: a project with no detectable lint/tests/build is a project that cannot prove its own work, and the verifier says so.

## What it detects

| Signal in the project | What runs |
|---|---|
| `package.json` + `package-lock.json` / no lockfile | `npm run lint/typecheck/test/build` |
| `package.json` + `pnpm-lock.yaml` | `pnpm run …` |
| `package.json` + `yarn.lock` | `yarn run …` |
| `package.json` + `bun.lock` / `bun.lockb` | `bun run …` |
| `Makefile` | `make lint/typecheck/test/build` (existing targets) |
| `justfile` | `just lint/typecheck/test/build` (existing recipes) |
| `Cargo.toml` | `cargo fmt --check` (when rustfmt present), `cargo test` |
| `go.mod` | `go vet ./...`, `go test ./...`, `go build ./...` |
| `pom.xml` | `./mvnw -B test` (wrapper preferred, `mvn` fallback) |
| `build.gradle` / `build.gradle.kts` | `./gradlew check` (wrapper preferred, `gradle` fallback) |
| `composer.json` | `composer run test` (when `scripts.test` is defined) |
| `deno.json` / `deno.jsonc` | `deno lint`, `deno test` |
| `CMakeLists.txt` | `cmake -S . -B <tmp> && cmake --build <tmp>` — the temp dir keeps the project tree untouched |
| `pyproject.toml` / `setup.py` + pytest | `poetry run pytest -q` with `poetry.lock` + poetry, else `python3 -m pytest -q` |
| `pyproject.toml` + ruff config | `ruff check .` |
| `.github/workflows/*.yml` | allowlisted single-line `run:` commands (below) |

Design rules:

- **The project's own config decides.** No toolchain is guessed; no command runs that the project doesn't already use somewhere.
- **Missing tooling is a declared `UNTESTED` note**, never a silent skip and never a hard crash.
- **Lockfile wins for package runners.** A `pnpm-lock.yaml` project runs `pnpm run …` when pnpm exists; when it doesn't, the fallback to npm prints a `(declared)` note.
- **Duplicates run once.** A command detected through both `package.json` and CI config runs a single time; the skip prints a receipt.

## CI-workflow detection

For projects whose only verification signal lives in CI config, the verifier extracts single-line `run:` commands from `.github/workflows/*.yml` and runs only exact matches from a fixed allowlist of canonical verification commands (`npm run test`, `pytest`, `make lint`, `go test ./...`, `cargo test`, `deno lint`, …).

Everything else — multiline blocks, pipes, variable interpolation, curl-pipe-sh, anything not on the list — is ignored by design. The verifier runs what the project's own CI runs, nothing more. Widening the allowlist requires a fixture in `selftest.sh` that proves the addition; see [CONTRIBUTING.md](../CONTRIBUTING.md).

## JSON mode

`--json` prints exactly one JSON document on stdout — everything else (declared fallbacks, missing-tool notes) joins the document instead of polluting it:

```json
{
  "tool": "ocd-verify",
  "version": "1.3.0",
  "project": "/abs/path",
  "commands": [
    {"label": "lint", "command": "npm run lint", "exit_code": 0, "tail": "..."}
  ],
  "notes": ["cargo test implies the build — no separate build step"],
  "summary": {"ran": 3, "failed": 0},
  "result": "PASS"
}
```

Exit codes are identical to human mode. The `tail` is the verbatim output tail, JSON-escaped (quotes, backslashes, newlines, tabs, carriage returns).

## Wiring it in

A `Makefile` target:

```make
verify:
	bash scripts/verify.sh .
```

A CI step:

```yaml
- name: OCD verify
  run: bash scripts/verify.sh .
```

Or bootstrap both the verifier and a Debt Ledger in one command with [`ocdify.sh`](OCDIFY.md).

## Self-proving

`selftest.sh` (via `make test`) proves this script with fixture projects: green and red suites, every detector's present-tool and absent-tool paths, package-manager selection, workflow allowlisting, dedup, and JSON mode. Fixtures needing absent tools skip with a declaration.
