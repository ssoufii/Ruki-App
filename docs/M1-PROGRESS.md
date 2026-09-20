# M1 Progress

Status: **IN PROGRESS** (change this line to `M1 COMPLETE` only per docs/M1-PLAYBOOK.md §5).

Statuses: `todo` · `in-progress` · `merged` · `partial` (merged, issue left open) · `blocked` · `deferred`.
Every story gets its own branch `m1/story-NNN-slug` (tasks: `m1/task-slug`), merged into `m1/integration` only when CI is green.

## Stories
| Order | Story | Branch | Status | Notes |
|---|---|---|---|---|
| 1 | #33 History on-device (SwiftData) | | todo | |
| 2 | #28 Streak in prayers | | todo | |
| 3 | #29 Late keeps streak | | todo | |
| 4 | #30 Pause freezes streak | | todo | |
| 5 | #31 Reset copy + lifetime + 30-day | | todo | |
| 6 | #35 Pause never in friend payload | | todo | |
| 7 | #18 Fajr adhan→sunrise | | todo | |
| 8 | #13 Time-Sensitive local notification | | todo | |
| 9 | #16 64-pending test | | todo | |
| 10 | #17 Disable Fajr independently | | todo | |
| 11 | #15 12 days forward + refresh | | todo | |
| 12 | T1 App shell (task) | | todo | |
| 13 | #14 Tap opens check-in | | todo | |
| 14 | #11 Intention screen | | todo | |
| 15 | #9 Onboarding madhab (partial by design) | | todo | |
| 16 | #10 Notification permission | | todo | |
| 17 | T2 Today screen (task) | | todo | |
| 18 | #12 Add-friends skippable / solo works | | todo | |
| 19 | #19 Prompt→capture flow | | todo | |
| 20 | #23 Caption | | todo | |
| 21 | #24 Immediate post | | todo | |
| 22 | #25 Late path | | todo | |
| 23 | #20 Dual capture, single retake | | todo | |
| 24 | #22 Space Only | | todo | |
| 25 | #21 Sequential fallback | | todo | |
| 26 | #27 Retake marker | | todo | |
| 27 | #26 Missed-prayer private mark | | todo | |
| 28 | #34 Pause ≤2 taps | | todo | |
| 29 | #32 Calendar grid | | todo | |
| 30 | #36 Settings | | todo | |
| 31 | #37 Export + delete (partial by design) | | todo | |
| 32 | T3 DEBUG tools (task) | | todo | |
| 33 | #8 Sign in (deferred to M2) | | deferred | |

## Findings (conflicts, surprises, things the next run must know)
- Session 5 (interactive): timeline + streak logic + debug clock were written and compile-checked but have **no unit tests yet**; the stories above add them.

## Run log
- (each routine run appends: date, stories attempted, outcomes, CI links)
