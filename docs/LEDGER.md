# ledger.sh — the Debt Ledger manual

The Debt Ledger is a running, severity-ordered list of known problems, stored in `DEBT_LEDGER.md` at the repo root — a file, not a metaphor. Sessions open by reading it and close by updating it; items get burned down proactively, without being asked.

`ledger.sh` maintains it mechanically, so agents (and humans) stop hand-editing the file and start keeping it honest.

## Usage

```bash
bash ocd/scripts/ledger.sh add "[High] checkout flow has no tests"
bash ocd/scripts/ledger.sh ls
bash ocd/scripts/ledger.sh burn 2
bash ocd/scripts/ledger.sh validate
```

The ledger path defaults to `./DEBT_LEDGER.md`; pass it as the last argument to point elsewhere.

## Commands

### add

```bash
bash ocd/scripts/ledger.sh add "[Medium] three components duplicate date formatting"
```

Appends an item. The text must start with a severity label; the script adds the list bullet itself. If no ledger exists, one is created from the OCD template — the skill's "no ledger? start one with your first finding," mechanized.

### ls

Lists the open items in file order, numbered. These numbers are what `burn` takes.

### burn

```bash
bash ocd/scripts/ledger.sh burn 2
```

Moves item 2 out of the open list and into a `## Burned` section at the bottom of the file, struck through and dated:

```markdown
## Burned

- ~~[High] checkout flow has no tests~~ burned 2026-11-19
```

Burned items are never deleted — history remembers what was fixed, and when. Surviving items renumber; run `ls` again to see the new order.

### validate

Checks that every open item carries a proper severity label. Exit `0` when the ledger is well-formed; exit `1` with the offending lines (file and line number) when it isn't.

## Severity labels

One vocabulary everywhere — findings, ledger entries, everything:

| Label | Meaning | Action |
|---|---|---|
| `[Critical]` | blocks merge/ship | security holes, data loss, broken functionality |
| `[High]` | must fix before done | bugs, failing tests, missing error handling on touched paths |
| `[Medium]` | should fix | worth weighing; fix when you touch the area |
| `[Low]` | optional | may ignore |
| `[FYI]` | informational | no action needed |

## The workflow it serves

1. **Open of session:** `ledger.sh ls` — know the debt before touching anything.
2. **During the work:** fix what you can, `add` what you find but won't fix now. Every session burns items or adds them; a session that does neither wasn't paying attention.
3. **Close of session:** `burn N` for everything fixed, then commit the ledger with the work. `validate` before committing keeps the format honest.

An empty ledger is a claim that nothing is wrong — make it because it's true, not because nobody looked.
