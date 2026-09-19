# MEMORY.md — Project State & Decision Log

Read alongside `CLAUDE.md` at the start of every session. Update at the end of every session.

---

## Current state

**Phase:** Pre-M0. Planning complete, no code written.
**Last session:** 2026-08-18 (session 2) — timing model, scope, and friend cap revised.
**Next action:** Resolve **OQ-8** (Toronto reference timetable) and **OQ-9** (Fajr window) — both block M1. Then begin M0: Xcode project, SPM setup, `ClockProviding`, `PrayerTimeProviding`, full-year Toronto golden-file tests.

**Nothing is built yet.** No repo, no Xcode project, no backend account.

---

## One-paragraph project summary

Ruki is an iOS app (Swift/SwiftUI, iOS 17+) that applies BeReal's mechanic to prayer accountability for Muslims. At a randomized moment inside each of the five daily prayer windows, a time-sensitive notification fires; the user has ~15 minutes to post an unfiltered dual-camera photo confirming they prayed. Mutually-approved friends (max 25) see check-ins in a 24-hour feed. Missed prayers are stored on-device only and never transmitted. The product's defining constraint is that it must create accountability without creating performance of worship.

---

## Decision log

Each entry: what was decided, why, and what would make us revisit. Do not silently contradict these — if a decision looks wrong, reopen it explicitly and log the change.

| # | Decision | Reasoning | Revisit if |
|---|---|---|---|
| D1 | iOS-only, iPhone-only, v1 | Focus. The camera + notification work is deeply platform-specific and doing it twice halves the quality of both. | Post-PMF |
| D2 | iOS 17 minimum | `@Observable`, SwiftData, modern SwiftUI. Coverage is high enough by launch that the cost is low. | Coverage data says otherwise |
| D3 | Adhan-Swift for prayer times | Mature, offline, supports all major methods and madhabs. Building this from solar-position math would be weeks of work and a correctness liability. Wrapped behind `PrayerTimeProviding` so it's swappable. | Adhan proves wrong at high latitude |
| D4 | Supabase for backend | Postgres RLS maps directly onto the mutual-friendship authorization model. Less lock-in than Firebase, ~6 weeks faster than Vapor. | Scale or cost problems; an all-Swift team preferring Vapor |
| D5 | Hybrid push + local notifications | Push alone breaks offline; local alone is gameable via device clock and unfixable without a client release. Both, with dedup. | — |
| D6 | Missed prayers never leave the device | RDP-2. A missed prayer is private. This is the line between accountability and surveillance, and it's also what keeps the app from being usable as a tool of coercion. | Never |
| ~~D7~~ | ~~Streaks private by default, sharing opt-in~~ **Superseded by D24** | | |
| D8 | No coordinates stored server-side | Prayer times compute on-device; server receives times only. A DB of identity + location + religious observance + social graph is dangerous in jurisdictions where Muslims are persecuted. | Never |
| D9 | Feed blurred until you check in | The BeReal mechanic that makes the loop work. Carries a real risk of incentivizing dishonest check-ins — flagged as OQ-7 for M4 testing. | OQ-7 testing shows users checking in without praying |
| D10 | No monetization in v1 | Charging for prayer help is a brand and possibly fiqh problem. | Post-PMF, cosmetic/storage only |
| D11 | No comments in feed (v1) | Reactions give encouragement; comments open a channel for judgment. Leaning toward permanent exclusion. | Strong user demand + a design that can't carry judgment |
| D12 | Engagement is an anti-metric | Optimizing time-in-app for a worship product pushes straight into riya'. North star is on-time check-in rate and self-reported improvement. | Never |
| D13 | Build solo loop (M1) before social (M2) | Timing reliability is the hard technical risk and the app must be valuable with zero friends anyway (R7). Front-loads the risk, gives a dogfoodable build at ~week 5. | — |
| D14 | `ClockProviding` injected everywhere; no direct `Date()` | Every serious bug in this product is a time bug. Untestable time logic = unfindable bugs. | Never |
| **D15** | **Prompt fires at adhan, not a randomized offset** — *supersedes the randomized algorithm in D-original §9* | Aligns with *awwal al-waqt* (praying early in the window is preferred); legible to users; creates simultaneous city-wide check-in bursts that make the feed feel alive. Cost: we lose the anti-pre-staging property. Acceptable — we never claimed to verify prayers. | Users report the prompt is indistinguishable from their existing adhan app |
| **D16** | **Check-in window 30 min; 20 min for Maghrib** | Maghrib's own prayer window is short; 30 min would consume most of it. Invariant `checkInWindow < prayerWindow` must hold all 365 days. | — |
| **D17** | **Fajr cannot use a fixed 30-min window** | Toronto Fajr is ~3:30 a.m. in June. A 30-min window would mark most genuine Fajr prayers as Late → guilt spiral (R5). Recommending Option A: window runs adhan → sunrise, matching the actual fiqh boundary. **Unresolved — OQ-9, blocks M1.** | — |
| **D18** | **Friend cap = 5 for MVP** (supersedes 25) | Resolves OQ-4 toward intimacy. Five people is a circle, not an audience — the strongest structural defence against riya'. Server-configurable so we can raise it. | M4 shows dead feeds from inactive friends |
| **D19** | **Toronto-only for MVP** | Removes time-zone, date-line, and high-latitude QA surface entirely. Lets us fetch prayer times once centrally instead of per-user. Out-of-area users get a waitlist, not wrong times. | Post-MVP; multi-city is priority #1 after launch |
| **D20** | **AlAdhan API, fetched server-side and cached — not called from the device** | Zero third-party calls from user devices (privacy, D8); no dependency on AlAdhan uptime at prayer time; one request/year instead of one per user per day; central `tune` corrections without a client release. Adhan-Swift bundled as offline fallback. | AlAdhan accuracy or availability problems |
| **D21** | **No location permission at MVP** | Toronto is assumed, so we don't need it. Removes a permission prompt from onboarding (conversion win) and strengthens the privacy position. Returns when we add cities. | Multi-city expansion |
| **D23** | **Friends' posts expire when the next prayer begins**, not at 24h | Removes any reason to browse (engagement is an anti-metric, D12) and shrinks data-at-rest to hours instead of a day. Tied to the *next* prayer rather than the post's own window because Fajr posts vanishing at sunrise would mean nobody who woke after ~5:30am ever saw one — and Fajr is where seeing your friends show up matters most. Uneven post lifetimes accepted. | Users report never seeing each other's posts |
| **D24** | **Streak is visible only to the user. No sharing mechanism at all** (supersedes D7) | D7 left a door open for opt-in reciprocal sharing. Closing it: a streak someone else can see is a number you are performing for, which is the exact failure RDP-1 exists to prevent. | Never |
| **D25** | **Streak counts consecutive prayers since the last miss, not days** | Five chances a day means a day-streak is all-or-nothing and reads as brutal. A prayer count moves five times a day, so progress is visible and a reset re-accumulates at a felt pace. Late counts; pause freezes rather than breaks (RDP-3); a privately self-marked prayer counts. Shown with lifetime total and 30-day rate so a reset erases one number out of three, not everything. | Churn-after-reset shows up in M4 |
| **D26** | **The user's own check-in history is kept forever, on-device only** | Your post leaving your friends' feeds and your record of having prayed are different things. The photo goes; the fact stays. On-device because a server-side religious-practice history is the dangerous artifact from D8. Cost: history doesn't survive device loss — fix with encrypted local backup, never a server copy. | Never (the on-device part) |
| **D22** | **Reactions are a single heart, gated on having checked in for that prayer** | One option rather than a set: choosing between responses imports judgment into a gesture that should carry none. A heart means "I saw you." The per-prayer gate matches the blurred-feed principle — participate before you respond. Poster sees who hearted; no count shown to anyone else, none aggregated. | A heart proves too thin to feel like encouragement |

---

## Standing constraints (do not violate)

- Absence of a check-in generates **no** network event, ever.
- Pause state appears in **no** friend-facing payload.
- There is **no** location column in the schema.
- Camera is unreachable until the user affirms the prayer is finished.
- Server timestamp determines on-time status, not the device's.
- No third-party analytics, ads, or attribution SDKs.

---

## Open questions (mirror of PRD §16)

- **OQ-1** Scholar review — who, and across which madhabs? *Launch gate.*
- ~~**OQ-2**~~ Is "Context" the final name? **Resolved: Ruki.**
- **OQ-3** Shia 3-session support in v1 or v1.1? Affects engine scope. *Needed before M1.*
- ~~**OQ-4**~~ Circle cap. **Resolved: 5 (D18).**
- **OQ-5** Comments: permanently excluded?
- **OQ-6** Should on-device missed-prayer records sync across the user's own devices?
- **OQ-7** Does the blurred-feed mechanic incentivize checking in without having prayed? *Test in M4.*
- **OQ-8** Which Toronto timetable is ground truth, and what `tune` offsets match it? *Blocks M1.*
- **OQ-9** Fajr window — Option A (adhan → sunrise, recommended), B (user-set prompt time), or C (fixed 30 min)? *Blocks M1.*
- **OQ-10** How do we detect and gate out-of-Toronto signups?

---

## Things I've been wrong about / corrections

*(Empty. Log corrections here rather than quietly fixing them — a future session needs to know what already failed.)*

---

## Session log

### 2026-08-18 — Session 1
- Created `PRD.md` (v0.1), `CLAUDE.md`, `MEMORY.md`.
- Established six Religious Design Principles as hard constraints, with the riya' risk and the never-broadcast-absence rule as the two that shape the most architecture.
- Chose Supabase, Adhan-Swift, iOS 17, hybrid notification scheduling.
- Estimated 14–19 weeks to launch, dogfoodable at ~5.
- **Raised as significant, unresolved:** the riya' concern needs qualified scholarly review before public launch, not just careful design. Also raised the surveillance risk of the dataset, which drove the no-server-side-location decision.
- No code written.

### 2026-08-18 — Session 2
User revised three things: prompt fires at adhan (not randomized), 30-min check-in window (20 for Maghrib), 5-friend cap, Toronto-only MVP with an API for prayer times.

- Logged D15–D21. Rewrote PRD §7.3, §8, §9, §7.5, §13, §16, and Appendix A.
- Verified AlAdhan API supports the parameters we need (`method`, `school`, `tune`, `latitudeAdjustmentMethod`; coordinate/city/address lookup; daily and annual calendar responses).
- **Argued for fetching AlAdhan server-side rather than from the device** — better privacy, no uptime dependency at prayer time, central corrections. User has not explicitly confirmed this variation on their instruction; re-confirm before building.
- **Flagged as the most important open problem: the Fajr window.** Toronto Fajr is ~3:30 a.m. in June; a fixed 30-min window would mark most genuine Fajr prayers as Late. This is the single change most likely to make the app feel punitive. OQ-9.
- **Flagged second: masjid timetable divergence.** Users trust their masjid's published times over a computed one. Need a chosen reference and `tune` offsets. OQ-8.
- Noted the cost of fixed timing: we no longer prevent photo pre-staging, and we risk reading as a generic adhan reminder. Neither is fatal, but copy and positioning have to carry more weight now.
- No code written.
