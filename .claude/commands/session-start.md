---
description: Load context, report project state, propose next work
---
Start-of-session protocol (CLAUDE.md).

1. Read `MEMORY.md` in full, then `CLAUDE.md`. Skim `docs/QA.md` "Known gaps".
2. Check reality against the notes: `git log --oneline -10`, `git status --short`, `gh run list --limit 3`. If MEMORY.md and the repo disagree, say so first — the repo is the truth, and MEMORY.md needs a correction entry.
3. Report, briefly: current milestone; what was last built/tested; what the last session said was **not** tested or uncertain; open questions blocking the next milestone.
4. Propose the next piece of work with its acceptance criteria. If criteria are unclear, ask exactly one question. Do not start building until the user agrees.
