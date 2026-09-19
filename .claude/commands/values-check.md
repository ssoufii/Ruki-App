---
description: Red-team the build against the Religious Design Principles. Release blocker.
---
Adversarial review of the current code against PRD §4 (RDP-1…6), CLAUDE.md "Domain rules", and MEMORY.md "Standing constraints". Read the code; don't rely on memory of it. For each question answer YES / NO / NOT APPLICABLE YET with evidence (file:line):

1. **Shame** — can any screen, string, colour, notification or empty state shame or scold a user? (Missed = neutral, no red, no "FAILED"; late = "still counts".)
2. **Absence leak (RDP-2)** — can any network event, payload, timing, or friend-visible UI reveal a missed prayer? Includes the heart-gating inference channel (PRD §7.6): nothing may sharpen it.
3. **Pause leak (RDP-3)** — does any friend-facing payload, or observable behaviour, reveal pause state?
4. **Camera during prayer (RDP-4)** — is the camera reachable before the user affirms they've finished?
5. **Performance over practice (RDP-1)** — is anything shareable, ranked, counted publicly, or engagement-optimised? Streaks visible to anyone but the user? Any sharing path?
6. **Location** — any location column, coordinate, or location permission?
7. **Arbitration (RDP-6)** — does anything tell a user their practice, madhab, or method is wrong? Note where v1 falls short of RDP-6 by design (3-session, Jumu'ah, traveler — D31, D32).
8. **Server authority** — is on-time status decided by a device timestamp anywhere?
9. **Third-party SDKs / analytics** — any added?

Any YES on 1–6, 8, 9 is a **release blocker**: say so plainly and propose no compromise version. Finish with a verdict line: BLOCKED or CLEAR-FOR-WHAT-EXISTS.
