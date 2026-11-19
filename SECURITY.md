# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| latest `v*` tag | yes |
| anything older | best effort |

## Reporting a vulnerability

Use GitHub's private vulnerability reporting: **Security** tab → **Report a vulnerability** on this repository. Please don't open a public issue for security problems.

Include what you found, how to reproduce it, and — if you have it — a fix. You'll hear back within a few days.

## Scope and design posture

OCD is a discipline skill plus a set of bash scripts. Its security posture is deliberately boring:

- **No network calls.** The scripts never fetch anything. The only "network" involved is whatever your own lint/test/build commands do.
- **No telemetry.** Nothing is reported anywhere. The scripts don't know you exist.
- **No dependencies.** Plain bash (3.2 compatible) plus the toolchain your project already uses.
- **Runs your project's own commands — by design.** `verify.sh` executes the lint/typecheck/test/build commands your project's config already declares. That is its job. Treat a verifier run like running your own CI locally.

### CI-workflow detection

The one place the scripts parse content they don't own — `.github/workflows/` — is deliberately conservative: only exact, allowlisted, canonical verification commands are executed. No pipes, no variable interpolation, no multiline blocks, no curl-pipe-sh. If you find a way to make the allowlist execute something a project's CI wouldn't, that's a vulnerability — report it.

### The skill text

`SKILL.md` is instructions for agents. If you see wording that induces dangerous behavior (running unreviewed commands, bypassing owner confirmation on destructive operations), report it with the same process.
