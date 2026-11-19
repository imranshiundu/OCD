#!/usr/bin/env bash
set -u

MAX_TAIL="${OCD_TAIL_LINES:-15}"
case "$MAX_TAIL" in ''|*[!0-9]*) MAX_TAIL=15 ;; esac

FAILED=0
RAN=0
RUN_KEYS=""

usage() {
  cat <<'EOF'
verify.sh — the OCD Zero-Error Exit Criteria, mechanically enforced.

Detects lint / typecheck / test / build commands from the project's own
config (package.json scripts, Makefile, justfile, Cargo.toml, go.mod,
pyproject.toml, pom.xml, build.gradle), follows the project's own package
manager (npm/pnpm/yarn/bun via lockfile, Maven/Gradle via wrapper), runs
each command once, and prints receipts: the command, its exit code, and
the verbatim tail of its output. A conservative GitHub-workflow pass
catches canonical verification commands in projects with no detectable
config.

Usage:
  verify.sh                            run against the current directory
  verify.sh /path/to/project           run against another project
  verify.sh --json                    machine-readable receipts (single JSON document)
  OCD_TAIL_LINES=40 verify.sh          longer verbatim receipts
  verify.sh -h                        this help
  verify.sh --version                 print version and exit

Exit codes:
  0  all detected commands green
  1  at least one command failed — fix and re-run
  2  no verification commands detected (untestable — itself a finding)
  64 usage error (unknown flag, extra path)
EOF
}

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="standalone"
[ -f "$HERE/../SKILL.md" ] && VERSION="$(sed -n 's/^  version: "\(.*\)"/\1/p' "$HERE/../SKILL.md" 2>/dev/null)"
[ -n "$VERSION" ] || VERSION="standalone"

JSON=0
PROJECT=""
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --version|-V) printf 'verify.sh (ocd %s)\n' "$VERSION"; exit 0 ;;
    --json) JSON=1 ;;
    -*) printf 'verify.sh: unknown flag %s\n' "$arg" >&2; exit 64 ;;
    *) if [ -n "$PROJECT" ]; then
         printf 'verify.sh: one project path only (got both %s and %s)\n' "$PROJECT" "$arg" >&2
         exit 64
       fi
       PROJECT="$arg" ;;
  esac
done
[ -n "$PROJECT" ] || PROJECT="."
if ! cd "$PROJECT" 2>/dev/null; then
  printf 'verify.sh: cannot enter %s\n' "$PROJECT" >&2
  exit 2
fi

has() { command -v "$1" >/dev/null 2>&1; }

JSON_CMDS=""
JSON_NOTES=""

json_escape() {
  local s="$1"
  s="${s//\\\\/\\\\\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

note() {
  # Informational lines (declared fallbacks, missing tooling). In JSON mode
  # they join the document instead of polluting parseable stdout.
  if [ "$JSON" -eq 1 ]; then
    JSON_NOTES="$JSON_NOTES\"$(json_escape "$1")\","
  else
    printf '%s\n' "$1"
  fi
}

run() {
  # Dedupe: a command detected twice (package.json *and* CI config, two
  # workflows) runs once. Package-manager aliases normalize to one key:
  # "npm run lint", "pnpm lint" and "yarn run lint" are all js:lint.
  local dkey
  dkey="$(printf '%s' "$2" | sed -E 's/^(npm|pnpm|yarn|bun) (run )?/js:/')"
  if printf '%s\n' "$RUN_KEYS" | grep -qxF -- "$dkey"; then
    note "── $2 — duplicate of an already-run command — skipped"
    return 0
  fi
  RUN_KEYS="$RUN_KEYS$dkey
"
  RAN=$((RAN + 1))
  local tmp code label cmd
  label="$1"
  cmd="$2"
  tmp="$(mktemp "${TMPDIR:-/tmp}/ocd-verify.XXXXXX")"
  [ "$JSON" -eq 0 ] && printf '\n── %s ──\n$ %s\n' "$label" "$cmd"
  shift 2
  "$@" >"$tmp" 2>&1
  code=$?
  if [ "$JSON" -eq 1 ]; then
    JSON_CMDS="$JSON_CMDS{\"label\":\"$(json_escape "$label")\",\"command\":\"$(json_escape "$cmd")\",\"exit_code\":$code,\"tail\":\"$(json_escape "$(tail -n "$MAX_TAIL" "$tmp" 2>/dev/null)")\"},"
    rm -f "$tmp"
    [ "$code" -eq 0 ] || FAILED=$((FAILED + 1))
    return 0
  fi
  printf 'exit: %s\n' "$code"
  if [ -s "$tmp" ]; then
    printf '── last %s lines (verbatim) ──\n' "$MAX_TAIL"
    tail -n "$MAX_TAIL" "$tmp"
  fi
  rm -f "$tmp"
  [ "$code" -eq 0 ] || FAILED=$((FAILED + 1))
}

js_script_key() {
  local key
  for key in "$@"; do
    if has node && node -e "process.exit(require('./package.json').scripts && require('./package.json').scripts['$key'] ? 0 : 1)" 2>/dev/null; then
      printf '%s' "$key"; return 0
    elif has bun && bun -e "const s=require('./package.json').scripts||{};process.exit(s['$key']?0:1)" 2>/dev/null; then
      printf '%s' "$key"; return 0
    elif grep -q "\"$key\":" package.json; then
      printf '%s' "$key"; return 0
    fi
  done
  return 1
}

if [ -f package.json ]; then
  # The runner follows the project's own lockfile when that binary exists.
  pm=npm
  if [ -f pnpm-lock.yaml ] && has pnpm; then pm=pnpm
  elif [ -f yarn.lock ] && has yarn; then pm=yarn
  elif { [ -f bun.lockb ] || [ -f bun.lock ]; } && has bun; then pm=bun
  elif has npm; then pm=npm
  else pm=none; fi
  if [ "$pm" = npm ]; then
    [ -f pnpm-lock.yaml ] && note 'pnpm-lock.yaml found but pnpm not on PATH — falling back to npm (declared)'
    [ -f yarn.lock ] && note 'yarn.lock found but yarn not on PATH — falling back to npm (declared)'
    { [ -f bun.lockb ] || [ -f bun.lock ]; } && note 'bun lockfile found but bun not on PATH — falling back to npm (declared)'
  fi
  if [ "$pm" = none ]; then
    note 'package.json found but no package manager on PATH (npm/pnpm/yarn/bun) — its scripts are UNTESTED'
  else
    js_run() {  # js_run <label> <script-key>
      case "$pm" in
        pnpm) run "$1" "pnpm run $2" pnpm run "$2" ;;
        yarn) run "$1" "yarn run $2" yarn run "$2" ;;
        bun)  run "$1" "bun run $2" bun run "$2" ;;
        *)    run "$1" "npm run $2" npm run "$2" ;;
      esac
    }
    key="$(js_script_key lint)" && js_run lint "$key"
    key="$(js_script_key typecheck type-check)" && js_run typecheck "$key"
    key="$(js_script_key test tests)" && js_run test "$key"
    key="$(js_script_key build)" && js_run build "$key"
  fi
fi

for mf in GNUmakefile makefile Makefile; do
  if [ -f "$mf" ] && has make; then
    for target in lint typecheck test build; do
      if grep -qE "^${target}:" "$mf"; then
        run "$target (make)" "make $target" make "$target"
      fi
    done
    break
  fi
done

for jf in justfile Justfile .justfile; do
  if [ -f "$jf" ] && has just; then
    for recipe in $(just --summary 2>/dev/null); do
      case "$recipe" in
        lint|typecheck|test|build) run "$recipe (just)" "just $recipe" just "$recipe" ;;
      esac
    done
    break
  fi
done

if [ -f Cargo.toml ] && has cargo; then
  if cargo fmt --version >/dev/null 2>&1; then
    run "lint (cargo fmt --check)" "cargo fmt --check" cargo fmt --check
  fi
  run "test (cargo test)" "cargo test" cargo test
  note '(cargo test implies the build — no separate build step)'
fi

if [ -f go.mod ] && has go; then
  run "lint (go vet)" "go vet ./..." go vet ./...
  run "test (go test)" "go test ./..." go test ./...
  run "build (go build)" "go build ./..." go build ./...
fi

if [ -f pom.xml ]; then
  if [ -x ./mvnw ]; then
    run "test (maven wrapper)" "./mvnw -B test" ./mvnw -B test
    note '(mvn test compiles and tests the project — no separate build step)'
  elif has mvn; then
    run "test (maven)" "mvn -B test" mvn -B test
    note '(mvn test compiles and tests the project — no separate build step)'
  else
    note 'pom.xml found but no ./mvnw or mvn on PATH — maven UNTESTED'
  fi
fi

if [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  if [ -x ./gradlew ]; then
    run "check (gradle wrapper)" "./gradlew check" ./gradlew check
  elif has gradle; then
    run "check (gradle)" "gradle check" gradle check
  else
    note 'gradle build file found but no ./gradlew or gradle on PATH — gradle UNTESTED'
  fi
fi

if { [ -f pyproject.toml ] || [ -f setup.py ]; } && has python3; then
  if [ -f ruff.toml ] || [ -f .ruff.toml ] || grep -q '\[tool\.ruff\]' pyproject.toml 2>/dev/null; then
    if has ruff; then
      run "lint (ruff check)" "ruff check ." ruff check .
    else
      note 'ruff configured but not installed — lint UNTESTED'
    fi
  fi
  if python3 -m pytest --version >/dev/null 2>&1; then
    if [ -d tests ] || find . -maxdepth 3 -name 'test_*.py' -not -path '*/node_modules/*' -not -path '*/.venv/*' -print -quit 2>/dev/null | grep -q .; then
      run "test (pytest)" "python3 -m pytest -q" python3 -m pytest -q
    fi
  fi
fi

# ── CI workflows: conservative safety net for projects with no detectable config ──
# Single-line `run:` commands are extracted from .github/workflows/*.yml|*.yaml,
# and only exact matches from a fixed allowlist of canonical verification commands
# are run — the same commands the project's own CI runs. Multiline blocks, pipes,
# variables, and anything else are skipped by design. Runs last so duplicates
# (also detected via package.json/Makefile/...) are deduped.
ci_allowlist='^(npm run |pnpm run |yarn run |bun run |npm |pnpm |yarn |bun )(lint|typecheck|type-check|test|tests|build)$|^(make|just) (lint|typecheck|test|build)$|^pytest( -q)?$|^python3? -m pytest(-q)?$|^ruff check( \.)?$|^eslint \.$|^tsc --noEmit$|^(go vet|go test|go build) \./\.\.\.$|^cargo (test|fmt --check)$|^deno (lint|test)$'
if [ -d .github/workflows ]; then
  ci_cmds="$(
    for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
      [ -f "$wf" ] || continue
      sed -n 's/^[[:space:]]*-\{0,1\}[[:space:]]*run:[[:space:]]*//p' "$wf"
    done | sort -u
  )"
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    printf '%s\n' "$cmd" | grep -qE "$ci_allowlist" || continue
    case "$cmd" in
      *build*)                      run "build (ci-workflow)"      "$cmd" sh -c "$cmd" ;;
      *typecheck*|*type-check*|tsc*) run "typecheck (ci-workflow)" "$cmd" sh -c "$cmd" ;;
      *test*)                       run "test (ci-workflow)"       "$cmd" sh -c "$cmd" ;;
      *)                            run "lint (ci-workflow)"       "$cmd" sh -c "$cmd" ;;
    esac
  done <<< "$ci_cmds"
fi

result=PASS
rc=0
if [ "$RAN" -eq 0 ]; then
  result=UNTESTABLE; rc=2
elif [ "$FAILED" -gt 0 ]; then
  result=FAIL; rc=1
fi

if [ "$JSON" -eq 1 ]; then
  printf '{"tool":"ocd-verify","version":"%s","project":"%s","commands":[%s],"notes":[%s],"summary":{"ran":%s,"failed":%s},"result":"%s"}\n' \
    "$(json_escape "$VERSION")" "$(json_escape "$PWD")" "${JSON_CMDS%,}" "${JSON_NOTES%,}" "$RAN" "$FAILED" "$result"
  exit "$rc"
fi

printf '\n════ verify.sh summary ════\n'
printf 'commands run: %s | failed: %s\n' "$RAN" "$FAILED"
if [ "$RAN" -eq 0 ]; then
  printf 'RESULT: UNTESTABLE — no verification commands detected.\nThis is itself a finding: set up the minimum (lint + tests) per the Zero-Error Exit Criteria.\n'
  exit 2
fi
if [ "$FAILED" -gt 0 ]; then
  printf 'RESULT: FAIL — %s of %s red. Fix and re-run; red plus "done" is a lie.\n' "$FAILED" "$RAN"
  exit 1
fi
printf 'RESULT: PASS — %s/%s green. Paste these receipts in the Evidence Block.\n' "$RAN" "$RAN"
exit 0
