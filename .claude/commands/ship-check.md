---
description: Full pre-release pass across PM, Engineer and QA roles
---
Pre-release pass. Say which role is speaking. Do not soften findings; a check that wasn't run is reported as NOT RUN.

**Product manager** — does the build match `PRD.md` (canonical for *what*)? Any scope creep toward a general Islamic app? Is the PRD current? Are all `MEMORY.md` decisions honoured?

**Engineer** — Debug *and* Release build from clean DerivedData with zero warnings; `check-no-date.sh` passes; no `fatalError` in shipping paths; every force unwrap has a why-comment; strings are in String Catalogs; Sendable/strict concurrency clean.

**QA** — run `/time-check` and `/values-check` (a values BLOCKED verdict stops the release). Notification delivery matrix (PRD §13) including the 64-pending ceiling; accessibility (VoiceOver, Dynamic Type AX5, reduced motion, non-colour-only on-time/late) and RTL.

**Hard gates (any one blocks):**
- `FixedPrayerTimeProvider` is still the provider in a build that goes to anyone but the builder (D27).
- Scholar review (OQ-1) not done, for a public launch.
- Any RDP violation.

End with: what was verified, what was not, what I'm unsure about.
