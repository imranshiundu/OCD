#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
VERIFY="$HERE/verify.sh"
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
  FIXTURES+=("$(mktemp -d)")
  FIX="${FIXTURES[-1]}"
}

expect_exit() {
  local desc="$1" want="$2" got tmp
  shift 2
  tmp="$(mktemp)"
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
  tmp="$(mktemp)"
  "$@" >"$tmp" 2>&1
  if grep -qE "$pattern" "$tmp"; then
    ok "$desc"
  else
    bad "$desc — output missing /$pattern/"
    tail -n 5 "$tmp" | sed 's/^/    /'
  fi
  rm -f "$tmp"
}

say "verify.sh selftest"

expect_exit "help flag exits 0" 0 bash "$VERIFY" -h
expect_output "help mentions exit codes" "Exit codes:" bash "$VERIFY" -h
expect_exit "missing directory exits 2" 2 bash "$VERIFY" /nonexistent-dir-xyz

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

if command -v make >/dev/null 2>&1; then
  new_fixture
  cat >"$FIX/Makefile" <<'EOF'
lint:
	@true
test:
	@true
EOF
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
  printf 'module fixture\n\ngo 1.21\n' >"$FIX/go.mod"
  expect_exit "go project runs vet/test/build" 0 bash "$VERIFY" "$FIX"
else
  skip "go fixture suite"
fi

say ""
say "selftest summary: $PASS passed, $FAIL failed, $SKIP skipped (all skips declared)"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
