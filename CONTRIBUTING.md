# Contributing to OCD

Thanks for helping make agents less lazy, less flattering, and more honest.

## Setup

```bash
git clone https://github.com/imranshiundu/OCD.git
cd OCD
make lint && make test && make verify
```

That's the same bar CI enforces on every push. If any of it is red on your machine, stop and fix that first — PRs from a red tree don't merge.

## Project layout

```
ocd/SKILL.md            the skill — the standard itself, agent-readable
ocd/scripts/verify.sh   the mechanical bar (Zero-Error Exit Criteria)
ocd/scripts/ocdify.sh   project bootstrapper
ocd/scripts/ledger.sh   debt ledger maintenance
ocd/scripts/selftest.sh the fixture suite proving all of the above
docs/                   per-script manuals
.github/                CI and release automation
```

## The one rule

A claim without a receipt doesn't merge. That applies to detectors, fixes, and docs alike: every behavior change ships with a fixture in `selftest.sh` that proves it, and every doc statement matches what the code actually does.

## Adding a detector

1. **Fixture first.** Add a green-path fixture (tool present) and a declared-untestable fixture (tool absent) to `selftest.sh`. Both must pass — the absent path skips with a declaration, exactly as the skill prescribes.
2. **Detection second.** Add the detection block in `verify.sh`, following the existing pattern: the project's own config decides, missing tooling prints a declared `UNTESTED` note.
3. **Docs.** A row in the detection matrix (README + `docs/VERIFY.md`).
4. **Changelog.** An entry under the unreleased version.

A detector without fixtures is a claim without receipts. It doesn't merge.

## Commit style

- Subject: imperative, 72 characters or fewer — "add cmake build support", not "added cmake"
- Body (when non-obvious): explain *why*, not *what* — the diff already says what
- Keep commits atomic: one behavior change per commit, tree green at every commit

## Pull requests

- Small and focused. A detector + its fixtures + its docs row is a perfect PR.
- `make lint && make test && make verify` green locally, CI green on both ubuntu and macOS.
- Describe the behavior change and name the fixtures that prove it.

## Releases

Semantic versioning. The version lives in `ocd/SKILL.md` frontmatter (`metadata.version`), the changelog gets the release entry, and pushing a `v*` tag publishes the GitHub release automatically — the workflow extracts the matching changelog section as the release body.

## Reporting problems

Bugs, detector requests, and allowlist proposals go to [issues](https://github.com/imranshiundu/OCD/issues). Security issues follow [SECURITY.md](SECURITY.md) — please don't open public issues for those.
