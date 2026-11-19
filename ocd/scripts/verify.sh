#!/usr/bin/env bash
set -u

MAX_TAIL="${OCD_TAIL_LINES:-15}"
case "$MAX_TAIL" in ''|*[!0-9]*) MAX_TAIL=15 ;; esac

FAILED=0
RAN=0

usage() {
  cat <<'EOF'
verify.sh — the OCD Zero-Error Exit Criteria, mechanically enforced.

Detects lint / typecheck / test / build commands from the project's own
config (package.json scripts, Makefile, justfile, Cargo.toml, go.mod,
pyproject.toml), runs each one, and prints receipts: the command, its
exit code, and the verbatim tail of its output.

Usage:
  scripts/verify.sh                     run against the current directory
  scripts/verify.sh /path/to/project    run against another project
  OCD_TAIL_LINES=40 scripts/verify.sh   longer verbatim receipts
  scripts/verify.sh -h                  this help

Exit codes:
  0  all detected commands green
  1  at least one command failed — fix and re-run
  2  no verification commands detected (untestable — itself a finding)
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

PROJECT="${1:-.}"
if ! cd "$PROJECT" 2>/dev/null; then
  printf 'verify.sh: cannot enter %s\n' "$PROJECT" >&2
  exit 2
fi

has() { command -v "$1" >/dev/null 2>&1; }

run() {
  RAN=$((RAN + 1))
  printf '\n── %s ──\n$ %s\n' "$1" "$2"
  local tmp code
  tmp="$(mktemp)"
  shift 2
  "$@" >"$tmp" 2>&1
  code=$?
  printf 'exit: %s\n' "$code"
  if [ -s "$tmp" ]; then
    printf '── last %s lines (verbatim) ──\n' "$MAX_TAIL"
    tail -n "$MAX_TAIL" "$tmp"
  fi
  rm -f "$tmp"
  [ "$code" -eq 0 ] || FAILED=$((FAILED + 1))
}

npm_script_key() {
  local key
  for key in "$@"; do
    if node -e "process.exit(require('./package.json').scripts && require('./package.json').scripts['$key'] ? 0 : 1)" 2>/dev/null; then
      printf '%s' "$key"
      return 0
    fi
  done
  return 1
}

if [ -f package.json ]; then
  if has node && has npm; then
    key="$(npm_script_key lint)" && run "lint" "npm run $key" npm run "$key"
    key="$(npm_script_key typecheck type-check)" && run "typecheck" "npm run $key" npm run "$key"
    key="$(npm_script_key test tests)" && run "test" "npm run $key" npm run "$key"
    key="$(npm_script_key build)" && run "build" "npm run $key" npm run "$key"
  elif has npm; then
    for key in lint typecheck type-check test tests build; do
      if grep -q "\"$key\":" package.json; then
        run "$key" "npm run $key" npm run "$key"
      fi
    done
  else
    printf 'package.json found but no node/npm on PATH — its scripts are UNTESTED\n'
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
  printf '(cargo test implies the build — no separate build step)\n'
fi

if [ -f go.mod ] && has go; then
  run "lint (go vet)" "go vet ./..." go vet ./...
  run "test (go test)" "go test ./..." go test ./...
  run "build (go build)" "go build ./..." go build ./...
fi

if { [ -f pyproject.toml ] || [ -f setup.py ]; } && has python3; then
  if [ -f ruff.toml ] || [ -f .ruff.toml ] || grep -q '\[tool\.ruff\]' pyproject.toml 2>/dev/null; then
    if has ruff; then
      run "lint (ruff check)" "ruff check ." ruff check .
    else
      printf 'ruff configured but not installed — lint UNTESTED\n'
    fi
  fi
  if python3 -m pytest --version >/dev/null 2>&1; then
    if [ -d tests ] || find . -maxdepth 3 -name 'test_*.py' -not -path '*/node_modules/*' -not -path '*/.venv/*' -print -quit 2>/dev/null | grep -q .; then
      run "test (pytest)" "python3 -m pytest -q" python3 -m pytest -q
    fi
  fi
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
