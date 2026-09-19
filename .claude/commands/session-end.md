---
description: Write this session into MEMORY.md
---
End-of-session protocol (CLAUDE.md). Update `MEMORY.md`:

1. **Current state** — phase, last session, next action, what exists / what doesn't.
2. **Decision log** — every non-obvious decision from this session, with reasoning and a "revisit if". Never silently change an existing decision: amend it visibly or supersede it.
3. **Corrections** — anything I got wrong earlier, said plainly.
4. **Open questions** — resolved ones struck through with the resolution.
5. **Session log entry** — what was built; what was tested (commands actually run and their results); **what was NOT tested**; what I'm uncertain about. The last two matter most. Do not describe anything as working that wasn't verified.
6. If behaviour changed, update `docs/ARCHITECTURE.md` and `docs/QA.md`; if scope or product changed, the PRD.
Do not commit unless asked.
