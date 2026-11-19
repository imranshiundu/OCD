---
name: Feature request
about: A new detector, flag, or workflow
labels: enhancement
---

**The problem**

What can't you do today? What breaks, or what lie does the current behavior let an agent tell?

**The proposal**

What should exist instead? For a new detector: the config signal it keys on and the exact command it should run.

**The fixtures that would prove it**

Every behavior change ships with fixtures in `selftest.sh` — the green path (tool present) and the declared-untestable path (tool absent). Sketch what they would look like. A detector without fixtures is a claim without receipts; it doesn't merge.
