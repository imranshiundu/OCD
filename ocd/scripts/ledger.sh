#!/usr/bin/env bash
set -u

usage() {
  cat <<'EOF'
ledger.sh — mechanical maintenance for DEBT_LEDGER.md.

The ledger is a file, not a metaphor. This script keeps it honest:
add findings, list them, burn them when fixed, validate the format.

Usage:
  ledger.sh add "<[Severity] description>" [path]
  ledger.sh ls [path]
  ledger.sh burn <n> [path]
  ledger.sh validate [path]

  path defaults to ./DEBT_LEDGER.md

Severity labels: [Critical] [High] [Medium] [Low] [FYI]

Commands:
  add        append an item (creates the ledger from the template if missing)
  ls         list open items in order, numbered
  burn <n>   move item n (as shown by ls) to the Burned section, dated today
  validate   exit 0 if every open item carries a proper severity label

Exit codes:
  0  ok (validate: no problems found)
  1  usage error, missing ledger, or validation failure
EOF
}

TEMPLATE='# Debt Ledger

Known problems, ordered by severity. Burn items down proactively; never walk past a defect.

Labels: [Critical] blocks ship — [High] must fix before done — [Medium]
should fix — [Low] optional — [FYI] informational
'

die() { printf 'ledger.sh: %s\n' "$1" >&2; exit 1; }

cmd="${1:-}"
case "$cmd" in
  -h|--help) usage; exit 0 ;;
  add|ls|burn|validate) ;;
  '') usage >&2; exit 1 ;;
  *) printf 'ledger.sh: unknown command %s\n' "$cmd" >&2; usage >&2; exit 1 ;;
esac
shift

case "$cmd" in
  add)
    text="${1:-}"
    [ -n "$text" ] || die 'add needs an item: ledger.sh add "[High] description"'
    path="${2:-DEBT_LEDGER.md}"
    case "$text" in '- '*) text="${text#- }" ;; esac
    case "$text" in
      '['*']'*) : ;;
      *) die 'item must start with a severity label, e.g. "[High] checkout has no tests"' ;;
    esac
    if [ ! -f "$path" ]; then
      printf '%s\n' "$TEMPLATE" > "$path"
      printf 'created: %s\n' "$path"
    fi
    if grep -q '^## Burned' "$path"; then
      # Insert before the Burned section — new items stay in the open list.
      tmp="$(mktemp "${TMPDIR:-/tmp}/ocd-ledger.XXXXXX")"
      awk -v item="- $text" '/^## Burned/ && !ins { print item; print ""; ins = 1 } { print }' "$path" > "$tmp"
      mv "$tmp" "$path"
    else
      printf -- '- %s\n' "$text" >> "$path"
    fi
    printf 'added to %s: %s\n' "$path" "$text"
    ;;

  ls)
    path="${1:-DEBT_LEDGER.md}"
    [ -f "$path" ] || die "no ledger at $path (start one: ledger.sh add \"[High] first finding\")"
    count="$(awk '/^- \[/{c++} END{print c+0}' "$path")"
    if [ "$count" -eq 0 ]; then
      printf 'no open items in %s\n' "$path"
    else
      awk '/^- \[/{n++; print n": "substr($0, 3)}' "$path"
    fi
    ;;

  burn)
    n="${1:-}"
    case "$n" in ''|*[!0-9]*) die 'burn needs an item number from ledger.sh ls' ;; esac
    path="${2:-DEBT_LEDGER.md}"
    [ -f "$path" ] || die "no ledger at $path"
    line="$(awk -v n="$n" '/^- \[/{c++; if (c==n) {print; exit}}' "$path")"
    [ -n "$line" ] || die "no open item number $n in $path"
    tmp="$(mktemp "${TMPDIR:-/tmp}/ocd-ledger.XXXXXX")"
    awk -v n="$n" '/^- \[/{c++; if (c==n) next} {print}' "$path" > "$tmp"
    grep -q '^## Burned' "$tmp" || printf '\n## Burned\n' >> "$tmp"
    printf -- '- ~~%s~~ burned %s\n' "${line#- }" "$(date +%Y-%m-%d)" >> "$tmp"
    mv "$tmp" "$path"
    printf 'burned from %s: %s\n' "$path" "${line#- }"
    ;;

  validate)
    path="${1:-DEBT_LEDGER.md}"
    [ -f "$path" ] || die "no ledger at $path"
    if awk '/^- \[/ && $0 !~ /^- \[(Critical|High|Medium|Low|FYI)\] / {bad=1; print FILENAME":"FNR": missing or wrong severity label: "$0} END{exit bad?1:0}' "$path"; then
      printf 'ledger valid: %s\n' "$path"
    else
      printf 'ledger invalid: fix the lines above\n' >&2
      exit 1
    fi
    ;;
esac
