# MEMORY.md — Project State & Decision Log

Read alongside `CLAUDE.md` at the start of every session. Update at the end of every session.

---

## Current state

**Phase:** M0 (foundations) complete. M1 (solo loop) not started.
**Last session:** 2026-09-19 (session 4) — verified M0, fixed the defects that surfaced, resolved the open decisions the user delegated, created `docs/` and `.claude/commands/`. Session 3 (the M0 build) never updated this file; its entry below is reconstructed from the commit.
**Next action:** Start M1 (solo loop). No decision blocks it. MVP backlog (65 stories, Epics 01–13, milestones M0–M3) is in GitHub Issues. The real prayer-time engine + OQ-8 (Epic 13) is the *first item of M2* — no friend can be added on frozen times (D27).

**What exists:** Xcode project (file-system synchronized groups, iOS 17.0, Swift 6, default actor isolation `nonisolated`); `ClockProviding`/`SystemClock`; protocol boundaries + fakes for prayer times, notifications, persistence, camera; `FixedPrayerTimeProvider` (D27); 15 test executions / 13 test functions (`RukiTests`); CI on GitHub Actions (passing on `a39bd3e`; the latest local changes are uncommitted and not yet through CI); `docs/QA.md`, `docs/ARCHITECTURE.md`, `.claude/commands/`.
**What does not exist:** any M1 feature, any UI beyond the Xcode template `ContentView`, any backend.

---

## One-paragraph project summary

Ruki is an iOS app (Swift/SwiftUI, iOS 17+) that applies BeReal's mechanic to prayer accountability for Muslims. At the adhan of each of the five daily prayers (D15), a time-sensitive notification fires; the user has 30 minutes (20 for Maghrib; Fajr runs adhan → sunrise) to post an unfiltered dual-camera photo confirming they prayed (D16, D17). Mutually-approved friends (max 5, D18) see check-ins in a feed where each post expires when the next prayer begins (D23). MVP is Toronto-only (D19). Missed prayers are stored on-device only and never transmitted. The product's defining constraint is that it must create accountability without creating performance of worship.

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
| **D16** | **Check-in window 30 min; 20 min for Maghrib** | Maghrib's own prayer window is short; 30 min would consume most of it. Invariant must hold all 365 days. **Amended 2026-09-19:** strict `checkInWindowEnd < end` for Dhuhr/Asr/Maghrib/Isha; Fajr is the one intentional equality (`==`, D17). The original wording (`<` for all) contradicted D17, and the first implementation used `<=` for all, which was too loose (see Corrections). | — |
| **D17** | **Fajr cannot use a fixed 30-min window — resolved: Option A** | Toronto Fajr is ~3:30 a.m. in June. A 30-min window would mark most genuine Fajr prayers as Late → guilt spiral (R5). **Resolved 2026-09-19: window runs adhan → sunrise**, matching the actual fiqh boundary. | — |
| **D18** | **Friend cap = 5 for MVP** (supersedes 25) | Resolves OQ-4 toward intimacy. Five people is a circle, not an audience — the strongest structural defence against riya'. Server-configurable so we can raise it. | M4 shows dead feeds from inactive friends |
| **D19** | **Toronto-only for MVP** | Removes time-zone, date-line, and high-latitude QA surface entirely. Lets us fetch prayer times once centrally instead of per-user. Out-of-area users get a waitlist, not wrong times. | Post-MVP; multi-city is priority #1 after launch |
| **D20** | **AlAdhan API, fetched server-side and cached — not called from the device** | Zero third-party calls from user devices (privacy, D8); no dependency on AlAdhan uptime at prayer time; one request/year instead of one per user per day; central `tune` corrections without a client release. Adhan-Swift bundled as offline fallback. **Confirmed 2026-09-19:** the user delegated the open decisions to me and I keep it — my session-2 argument stands and nothing since has weakened it. | AlAdhan accuracy or availability problems |
| **D21** | **No location permission at MVP** | Toronto is assumed, so we don't need it. Removes a permission prompt from onboarding (conversion win) and strengthens the privacy position. Returns when we add cities. | Multi-city expansion |
| **D23** | **Friends' posts expire when the next prayer begins**, not at 24h | Removes any reason to browse (engagement is an anti-metric, D12) and shrinks data-at-rest to hours instead of a day. Tied to the *next* prayer rather than the post's own window because Fajr posts vanishing at sunrise would mean nobody who woke after ~5:30am ever saw one — and Fajr is where seeing your friends show up matters most. Uneven post lifetimes accepted. | Users report never seeing each other's posts |
| **D24** | **Streak is visible only to the user. No sharing mechanism at all** (supersedes D7) | D7 left a door open for opt-in reciprocal sharing. Closing it: a streak someone else can see is a number you are performing for, which is the exact failure RDP-1 exists to prevent. | Never |
| **D25** | **Streak counts consecutive prayers since the last miss, not days** | Five chances a day means a day-streak is all-or-nothing and reads as brutal. A prayer count moves five times a day, so progress is visible and a reset re-accumulates at a felt pace. Late counts; pause freezes rather than breaks (RDP-3); a privately self-marked prayer counts. Shown with lifetime total and 30-day rate so a reset erases one number out of three, not everything. | Churn-after-reset shows up in M4 |
| **D26** | **The user's own check-in history is kept forever, on-device only** | Your post leaving your friends' feeds and your record of having prayed are different things. The photo goes; the fact stays. On-device because a server-side religious-practice history is the dangerous artifact from D8. Cost: history doesn't survive device loss — fix with encrypted local backup, never a server copy. | Never (the on-device part) |
| **D22** | **Reactions are a single heart, gated on having checked in for that prayer** | One option rather than a set: choosing between responses imports judgment into a gesture that should carry none. A heart means "I saw you." The per-prayer gate matches the blurred-feed principle — participate before you respond. Poster sees who hearted; no count shown to anyone else, none aggregated. | A heart proves too thin to feel like encouragement |
| **D27** | **MVP builds against a frozen, hand-captured prayer-time snapshot instead of live AlAdhan** | Real engine (D20) needs OQ-8 resolved first and adds a server fetch job before any code can run. A `FixedPrayerTimeProvider` conforming to the same `PrayerTimeProviding` protocol (D3) unblocks M0/M1 immediately with today's real Toronto times, frozen. **Explicit constraint: never ships to a user beyond the builder** — Toronto Fajr swings ~3:30 a.m.–6:00 a.m. across the year, so frozen times go wrong fast in either direction. Real engine work tracked separately. **Clarified 2026-09-19:** it lands as the *first item of M2*, before any friend can be added. (An earlier commit message said "M3"; that was wrong — M3 is hardening and is too late.) | Any build reaching a second real user before the real engine (D20) lands |

| **D28** | **Default actor isolation is `nonisolated`; Swift language mode 6.0; deployment target iOS 17.0** *(logged retroactively from session 3)* | Xcode 26's template sets `MainActor` default isolation, deployment target 26.2, and Swift 5. Default-MainActor pins every type to the main actor, which breaks Core's premise: the protocol boundaries must be callable from background contexts (BGAppRefreshTask, notification scheduling). iOS 17 is PRD §10.1 / D2. | A Core type genuinely needs main-actor isolation (annotate that type instead) |
| **D29** | **`RukiUITests` is excluded from CI until M1** *(logged retroactively from session 3)* | It's still Xcode's empty template, and XCUITest needs an accessibility session that isn't reliably available in CI. CI runs `-only-testing:RukiTests`. | M1 gives the UI test target real content — re-enable then, and add a values check on the UI |
| **D30** | **Isha's prayer window ends at the next day's Fajr adhan** (not midnight) | PRD Appendix A left it as "midnight (or Fajr)". The window is where a check-in is still accepted (Late). Ending at midnight would *refuse* a valid Isha prayed at 12:30 a.m. — the app would be telling someone their practice is wrong (RDP-6) and creating exactly the guilt R5 warns about. Ending at Fajr never refuses a valid prayer. It costs nothing structurally: D23 already expires posts at the next prayer, and Late-still-counts keeps the tone right. **This is a check-in boundary, not a fiqh ruling** — I am not a scholar; OQ-1 review may revise it, and the copy must never call midnight–Fajr "worse." | Scholar review says otherwise; M4 shows post-midnight Isha check-ins are noise |
| **D31** | **Shia 3-session support ships in v1.1, not v1** *(resolves OQ-3)* | It changes the shape of the engine (prompts per day, merged windows, which adhan a combined prompt fires at — the last needs a knowledgeable answer, not my guess), and doing it half-right violates RDP-6 more than a labelled deferral. The MVP is Toronto-only and dogfooded by the builder. Design constraint now: keep `Prayer` = five cases and the window model per-prayer, so combining is an overlay in the scheduler, not a schema change. **Cost, stated plainly:** v1 falls short of RDP-6 for combining users — they get five prompts, and prayers they pray combined may read as Late. `/values-check` should list this as a known shortfall, and the roadmap should not slip past v1.1. | The first TestFlight cohort includes combining users who churn on this |
| **D32** | **Jumu'ah is a fast-follow (PRD §7.10); MVP surfaces Friday Dhuhr as `.dhuhr`, but the data model reserves `jumuah`** | CLAUDE.md rule 8 said "its own prayer type" while the PRD (which wins on *what*) makes it P1 and `Prayer.swift` says display-only. Reconciled: the engine enum stays five cases; `CheckIn.prayer` (M1 SwiftData model) includes `jumuah` from day one so no migration is needed later. CLAUDE.md rule 8 reworded to match. | Jumu'ah is pulled into MVP |

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
- ~~**OQ-3**~~ Shia 3-session support. **Resolved: v1.1 (D31).**
- ~~**OQ-4**~~ Circle cap. **Resolved: 5 (D18).**
- **OQ-5** Comments: permanently excluded?
- **OQ-6** Should on-device missed-prayer records sync across the user's own devices?
- **OQ-7** Does the blurred-feed mechanic incentivize checking in without having prayed? *Test in M4.*
- **OQ-8** Which Toronto timetable is ground truth, and what `tune` offsets match it? No longer blocks M1 (D27). **Blocks M2** — needed before the real engine, which is the first item of M2.
- ~~**OQ-9**~~ Fajr window. **Resolved: Option A (adhan → sunrise).**
- **OQ-10** How do we detect and gate out-of-Toronto signups?

---

## Things I've been wrong about / corrections

*Log corrections here rather than quietly fixing them — a future session needs to know what already failed.*

- **PRD/CLAUDE.md drift I found and fixed while updating:** the PRD still had location permission in onboarding (D21), "24-hour expiry" (D23), and "OQ-8 blocks M1" (D27); CLAUDE.md listed a `docs/DECISIONS.md` that would only duplicate this file, and rule 8 conflicted with PRD §7.10 (D32). Session 2 said it rewrote the PRD but missed these.
- **This file went stale for one whole build session.** Session 3 built M0 and did not update MEMORY.md, so a fresh session would have read "Pre-M0, no code written." Violates the session protocol in CLAUDE.md.
- **The Maghrib invariant is weaker than D16 states, and its test title overstates it.** D16 says `checkInWindow < prayerWindow`; `PrayerWindow.satisfiesCheckInWindowInvariant` is `checkInWindowEnd <= end && checkInWindowEnd > start`, and the test's display name and the doc comment say "never reaches or exceeds." The `<=` is correct for Fajr (Option A makes them equal by design, and a test asserts it), but the check applies to all five prayers, so a Dhuhr/Asr/Maghrib/Isha window with `checkInWindowEnd == end` — zero Late phase — would pass. **Fixed 2026-09-19:** strict `<` for the four non-Fajr prayers, `==` required for Fajr; D16 amended; three new tests assert the invariant *rejects* zero-Late-phase, overrun, and clamped-Fajr windows (the old check would have passed the first).

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

### 2026-09-19 — Session 3 (M0 build) — *reconstructed from commit `a39bd3e`; the session did not log itself*
- Built RUKI-002 through RUKI-007 (GitHub issues #2–#7): `ClockProviding` + `SystemClock` (only permitted `Date()` site) with `scripts/check-no-date.sh` in CI; protocol boundaries + fakes; `FixedPrayerTimeProvider` (D27, approximate ISNA times for Toronto on 2026-09-19); Maghrib-invariant and window-ordering tests; GitHub Actions CI.
- Resolved OQ-9 → Option A (D17). Fixed Xcode 26 template defaults (D28). Excluded UI tests from CI (D29).
- **Wording conflict (resolved in session 4):** commit `a1a443a` says the real engine is deferred to "M3"; this file and the provider's doc comment said "before M2/TestFlight." Decided: first item of M2 (see D27).
- I don't know what else that session tested or was unsure about; nothing was recorded.

### 2026-09-19 — Session 4 (verification, fixes, and the decisions the user delegated)
User asked for a status, then to run the tests and update this file, then delegated all open decisions to me ("make a decision as to what is best for the vision") and asked me to complete the outstanding problems.

**Found:** this file was stale; the Maghrib invariant was `<=` for all prayers (looser than D16, and the test title overstated it); the 8 "tests" included an empty template placeholder; the tests covered one frozen day with no DST; PRD, README, CLAUDE.md contradicted decisions D21/D23/D27; `docs/` and `.claude/commands/` didn't exist.

**Built / changed:**
- `PrayerWindow.satisfiesCheckInWindowInvariant`: strict `<` except Fajr `==`.
- `FixedPrayerTimeProvider`: Isha now ends at next day's Fajr (D30) instead of next midnight.
- Removed the empty `RukiTests.example()`. Added `RukiTests/TimeEdgeCases/FixedProviderTimeEdgeCaseTests.swift`: 366-day sweep × both madhabs, both 2026–27 DST transitions, leap day, Isha→Fajr across year rollover, and three tests that the invariant rejects bad windows.
- Decisions D30, D31, D32; amended D16, D20, D27; resolved OQ-3; OQ-8 now blocks M2, not M1.
- PRD (§4 RDP-5/6, §7.1, §7.3, §9.2, §14, §16, Appx A), README status, CLAUDE.md (layout, rule 8) brought in line.
- Created `docs/QA.md`, `docs/ARCHITECTURE.md`, and the five slash commands.

**Tested (commands actually run):**
- `scripts/check-no-date.sh` — pass.
- `xcodebuild test -only-testing:RukiTests`, iPhone 17 simulator, Xcode 26.3, **fresh DerivedData**: 15 executions / 13 functions, 0 failed, zero compiler warnings. (The device-level count is per-argument; the top-level count is per-function — that was the earlier 8-vs-7 discrepancy.)
- Release configuration build for the simulator — succeeded, zero warnings.
- CI on GitHub passed for `a39bd3e` (the M0 commit). **The changes from this session are uncommitted, so CI has not seen them.**

**NOT tested:**
- **Anything seasonal.** The fixed provider returns the same wall-clock times every day, so the year sweep proves the invariant's shape, not its safety: it cannot see Maghrib shrinking in winter, Fajr drifting, or Isha past 10 p.m. Real coverage waits on the real engine and full-year golden files (M2, first item).
- Notification scheduling across the March DST boundary — nothing schedules yet.
- Physical device, UI tests (`RukiUITests` is still the empty template, D29), accessibility, RTL.
- I did not run the new slash commands or check they parse; they're untested prose.
- I did not mutation-test beyond the three rejects-bad-window tests (by inspection they would have failed against the old `<=` check; I didn't revert the fix to prove it).

**Uncertain about:**
- **D30 (Isha to Fajr) is a product judgment about a fiqh-adjacent boundary.** I'm confident it avoids refusing a valid prayer; I'm not qualified to say it's the right window, and the wording in the app must never imply it is. Needs the scholar review (OQ-1).
- **D31's cost is real.** Combining users get a five-prompt app in v1. I judged a labelled deferral better than a half-built profile, but it is a trade against RDP-6, not a free choice.
- SourceKit showed a "No such module 'Testing'" diagnostic on the new test file even though the build passes; I treated it as indexing noise and didn't investigate.
