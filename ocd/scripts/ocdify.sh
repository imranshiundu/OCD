#!/usr/bin/env bash
set -u

usage() {
  cat <<'EOF'
ocdify.sh — bootstrap OCD into any project: mechanical verifier + Debt Ledger.

Usage:
  ocd/scripts/ocdify.sh /path/to/project       install verifier + ledger
  ocd/scripts/ocdify.sh /path/to/project -f    replace an existing verifier copy
  ocd/scripts/ocdify.sh /path/to/project -c    check only — plan, touch nothing
  ocd/scripts/ocdify.sh -h                     this help
  ocd/scripts/ocdify.sh --version              print version and exit

What it does:
  1. Copies this skill's verify.sh to <project>/scripts/verify.sh
     (an existing copy is kept — pass -f to replace it)
  2. Creates <project>/DEBT_LEDGER.md from the OCD template if missing
     (an existing ledger is never touched, even with -f — it is the owner's data)
  3. Prints what was installed, what was skipped, and how to wire it up

Exit codes:
  0  project is OCD-compliant (changes made, or already compliant)
  1  usage error, target missing, or source verifier not found
  3  --check only: the project needs work (nothing was touched)
EOF
}

FORCE=0
CHECK=0
PROJECT=""
VERSION="standalone"
[ -f "$(cd "$(dirname "$0")" && pwd)/../SKILL.md" ] && VERSION="$(sed -n 's/^  version: "\(.*\)"/\1/p' "$(cd "$(dirname "$0")" && pwd)/../SKILL.md" 2>/dev/null)"
[ -n "$VERSION" ] || VERSION="standalone"
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --version|-V) printf 'ocdify.sh (ocd %s)\n' "$VERSION"; exit 0 ;;
    -f|--force) FORCE=1 ;;
    -c|--check) CHECK=1 ;;
    -*) printf 'ocdify.sh: unknown flag %s\n' "$arg" >&2; usage >&2; exit 1 ;;
    *) if [ -n "$PROJECT" ]; then
         printf 'ocdify.sh: one project path only (got both %s and %s)\n' "$PROJECT" "$arg" >&2
         exit 1
       fi
       PROJECT="$arg" ;;
  esac
done

if [ -z "$PROJECT" ]; then
  usage >&2
  exit 1
fi

if [ ! -d "$PROJECT" ]; then
  printf 'ocdify.sh: %s is not a directory\n' "$PROJECT" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/verify.sh"
if [ ! -f "$SRC" ]; then
  printf 'ocdify.sh: verifier not found next to me at %s\n' "$SRC" >&2
  exit 1
fi

# 0. Check mode: plan, touch nothing.
if [ "$CHECK" -eq 1 ]; then
  NEED=0
  if [ -f "$PROJECT/scripts/verify.sh" ]; then
    printf 'ok: %s/scripts/verify.sh present\n' "$PROJECT"
  else
    printf 'would install: %s/scripts/verify.sh\n' "$PROJECT"
    NEED=1
  fi
  if [ -f "$PROJECT/DEBT_LEDGER.md" ]; then
    printf 'ok: %s/DEBT_LEDGER.md present\n' "$PROJECT"
  else
    printf 'would create: %s/DEBT_LEDGER.md\n' "$PROJECT"
    NEED=1
  fi
  if [ "$NEED" -eq 0 ]; then
    printf 'compliant — nothing to do\n'
    exit 0
  fi
  exit 3
fi

# 1. Install the mechanical verifier.
if [ -f "$PROJECT/scripts/verify.sh" ] && [ "$FORCE" -ne 1 ]; then
  printf 'skipped: %s/scripts/verify.sh already exists (pass -f to replace)\n' "$PROJECT"
else
  mkdir -p "$PROJECT/scripts"
  cp "$SRC" "$PROJECT/scripts/verify.sh"
  chmod +x "$PROJECT/scripts/verify.sh"
  printf 'installed: %s/scripts/verify.sh\n' "$PROJECT"
fi

# 2. Bootstrap the Debt Ledger — the owner's data, never overwritten.
if [ -f "$PROJECT/DEBT_LEDGER.md" ]; then
  printf 'skipped: %s/DEBT_LEDGER.md already exists (never overwritten — owner data)\n' "$PROJECT"
else
  cat >"$PROJECT/DEBT_LEDGER.md" <<'EOF'
# Debt Ledger

Known problems, ordered by severity. Opened every session, updated every
session; burn items down proactively. An untouched ledger means an
inattentive session.

Labels: [Critical] blocks ship — [High] must fix before done — [Medium]
should fix — [Low] optional — [FYI] informational

- [FYI] Bootstrapped by ocdify (OCD — Obsessive Code Discipline). Replace this line with the first real finding.
EOF
  printf 'created: %s/DEBT_LEDGER.md\n' "$PROJECT"
fi

# 3. How to wire it up.
printf '\nNext moves:\n'
printf '  cd %s && bash scripts/verify.sh .    # run the mechanical bar\n' "$PROJECT"
printf '  # optional Makefile target:\n'
printf '  #   verify:\n'
printf '  #           bash scripts/verify.sh .\n'
printf 'Commit both files so every contributor — human and agent — inherits the bar.\n'
exit 0
