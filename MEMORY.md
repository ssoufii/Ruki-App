# MEMORY.md — Project State & Decision Log

Read alongside `CLAUDE.md` at the start of every session. Update at the end of every session.

---

## Current state

**Phase:** M0 (foundations) complete. M1 (solo loop) in progress, built by the unattended cloud routine (D39).
**Last session:** 2026-09-20 (session 7, scheduled M1 routine, run 2) — merged 6 more branches into `m1/integration` (15 of 33 M1 stories/tasks now merged or partial: adds #17, #15 (partial), T1 app shell, #11, #9 (partial), #10), all green on CI, every one on the first attempt.
**Next action:** Continue the M1 story order in `docs/M1-PLAYBOOK.md` §4. #14 was deliberately skipped out of order (needs the check-in cover screen, #19, which doesn't exist yet — see `docs/M1-PROGRESS.md` Findings) — the next unblocked story is T2 (Today screen), which #12 (add-friends step) also needs before onboarding can be completed end-to-end. The real prayer-time engine + OQ-8 (Epic 13) is still the *first item of M2* — no friend can be added on frozen times (D27).

**What exists:** everything from session 6, plus: `UserSettings` (`@MainActor @Observable`, UserDefaults-backed madhab/window/enabledPrayers/sound/spaceOnly/onboarding) + `PromptInputs`; a 12-day notification-scheduling horizon (`PromptRefreshCoordinator`) and a submit-only `BGTaskScheduler` wrapper (`BackgroundRefreshScheduling`/`SystemBackgroundRefreshScheduler`/`BackgroundRefresh`) — built but **not wired to any trigger yet**; the app shell (`AppEnvironment` composition root, `AppRouter`, `RootView`, `RukiPalette` design tokens); a real onboarding flow (`OnboardingFlow` sequencing `MadhabSelectionView` → `NotificationPermissionView` → `IntentionView`) replacing the Xcode template `ContentView`, which is now deleted. Layout now matches CLAUDE.md's repo table: `Ruki/App/`, `Ruki/DesignSystem/`, `Ruki/Features/Onboarding/`.
**What does not exist:** any backend; anything invoking `BackgroundRefresh`/`PromptScheduler` on a real trigger (needs T2's Today screen and #34's pause, not #15 itself — #15 built the logic, not the callers); the Today screen itself (still a placeholder in `RootView`); add-friends onboarding step (#12); notification-tap routing (#14, deliberately deferred); camera capture; calculation-method selection and 3-session practice profiles (out of scope for v1 — D31/D34, #9 only did Asr madhab); Sign in with Apple (#8, deferred to M2, D35).

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

| **D33** | **The check-in window setting (10/15/30 min) can only *shorten* the default; Fajr ignores it** | Stories/PRD §7.9 offer 10/15/30, which collides with D16 (30 default, Maghrib 20). Taking `min(setting, default)` keeps the Maghrib invariant and Fajr's adhan→sunrise (D17) intact by construction. A shorter window means more Late, so it is the user's own private choice, default 30. Implemented in `PrayerTimeline.onTimeEnd`. | A user wants a *longer* window than default |
| **D34** | **Calculation method is read-only in M1 ("ISNA, Toronto"); only Asr madhab is selectable** | `FixedPrayerTimeProvider` ignores the method (D27), so a picker would be a control that does nothing — misleading for the person dogfooding it. Becomes selectable with the real engine. | Real engine (first item of M2) lands |
| **D35** | **Sign-in (#8) is deferred to M2; M1 has no accounts** | M1 is "fully usable alone, no backend" (D13). Sign in with Apple needs an entitlement I can't verify against the user's Apple team, and phone auth needs an SMS backend. Building an untestable half is worse than deferring. #37 becomes "export/delete on this device"; server-side deletion joins M2. | M2 starts |
| **D36** | **Narrow exception to "never edit project.pbxproj": build-setting lines only, plus `Config/Ruki-Info.plist`. No entitlements added.** | The camera usage string and BG-task identifiers can't be expressed without a merged plist, and a missing camera string crashes the app on first capture. Change is 6 lines of build settings (INFOPLIST_FILE, portrait-only, iPhone-only), no file registration. Time-Sensitive and Sign in with Apple entitlements are NOT added: if the user's team can't sign them the app won't build on their phone. `interruptionLevel = .timeSensitive` is set in code; it will pierce Focus only once the user adds the Time Sensitive Notifications capability in Xcode. | Team capabilities confirmed |
| **D37** | **Local photos live only until the next prayer begins; the record stays forever** | D26 says "the photo goes; the fact stays." Keeping every prayer selfie on-device forever is unneeded, storage-heavy, and a risk (photos taken at home). `expiresAt` = next prayer start, matching the post lifetime (D23); a purge runs on launch/refresh. Export excludes photos. | Users want their own photo archive (would be opt-in) |
| **D38** | **Pause covers any prayer window it overlaps** (not only ones that start inside it) | Pausing mid-Asr must not turn that Asr into a miss when the pause ends — freezing must never break a streak (RDP-3). | — |
| **D39** | **M1 is built by an unattended hourly cloud routine, one branch per story, CI-gated, with a final verification and auto-merge to main** *(authorized by the user 2026-09-20)* | Branches `m1/story-NNN-*` off `m1/integration`; a story merges only on green macOS CI; playbook in `docs/M1-PLAYBOOK.md`, state in `docs/M1-PROGRESS.md`. Cloud sandbox is Linux (no Xcode), so CI is the only compiler/test runner; **hardware-only checks (real camera, notification delivery, Time-Sensitive, BG refresh) are listed but cannot be gated.** The user explicitly allowed auto-merge to `main` after all automated levels pass. Cadence is hourly, ~6 stories/run, because routines cannot run more often than hourly. | The routine produces red or low-quality merges |

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
- CI on GitHub (`macos-15`) passed for both `a39bd3e` (M0) and `913ad8d` (this session's changes, pushed after the local run above).

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

### 2026-09-20 — Session 6 (scheduled M1 routine, run 1)
Ran unattended per `docs/M1-PLAYBOOK.md`/D39. `gh` CLI is not installed in this sandbox at all (not just unauthenticated) — used the GitHub MCP server tools instead (this session's environment says to prefer them over `gh`/raw API access generally), verified they actually worked before relying on them, and logged the substitution in `docs/M1-PROGRESS.md` Findings per playbook §3 rather than silently swapping tools or treating it as the "no CI visibility" stop condition.

**Built, tested (CI, macOS-15/Xcode 16.4), and merged to `m1/integration`** — 5 branches, 9 stories:
- `m1/story-033-history-swiftdata` (#33): on-device SwiftData history.
- `m1/story-028-streak-tests` (#28, #29, #30, #31): streak/resolver unit tests + `StreakSummaryPresenter`.
- `m1/story-035-friend-payload` (#35): `FriendFacingCheckIn` + leak tests.
- `m1/story-018-fajr-window-tests` (#18): `PrayerTimeline` tests proving Fajr is never Late.
- `m1/story-013-time-sensitive-notification` (#13, #16): notification scheduling capped at 64.

Full details (branch names, CI run URLs, per-story notes) are in `docs/M1-PROGRESS.md`, not duplicated here.

**Two CI failures fixed, both Swift 6 strict-concurrency, worth remembering:**
- A `static let` of a non-`Sendable` type (SwiftData's `Schema`) doesn't compile under strict concurrency — made it a computed `static var`.
- A class storing `UNUserNotificationCenter` (not an audited-`Sendable` Apple type) as a stored property needs `@unchecked Sendable` with a justifying comment (both wrapper types hold only the shared `.current()` singleton and nothing else).
- Also fixed one unrelated test-file bug: `dict?.keys ?? []` doesn't type-check (`Dictionary.Keys` isn't `ExpressibleByArrayLiteral`) — coalesce the dictionary itself instead.

**NOT tested:** anything on a physical device or Simulator UI — this run was Core/ logic only (persistence, streak/resolver, a payload shape, Fajr-window logic, notification *scheduling* logic, not *delivery*). `UserNotificationScheduler`'s real `UNUserNotificationCenter` calls, `.timeSensitive` actually piercing Focus/DND, and permission-prompt behavior are exercised only through the protocol/fake in tests.

**Uncertain about:** whether `@unchecked Sendable` is the idiomatic long-term answer for the two notification wrapper types vs. actor-isolating them — chose it because both hold no other mutable state, but didn't find an authoritative Apple recommendation either way.

Stopped at 5 branches (playbook allows up to 6): #17 (`UserSettings` + per-prayer enable/disable) is a larger unit than the remaining run had room to implement, test, and drive through a full CI cycle including a possible fix-and-retry, and starting it without finishing would risk leaving `m1/integration` in a worse state than starting it.

### 2026-09-20 — Session 5 (M1 kickoff; handed to a cloud routine)
- Read all 30 M1 issues; found four that conflict with earlier decisions (#8, #9, #36, #37) and resolved them as D33–D35. Logged D36–D39.
- Wrote and compile-checked (Debug build succeeded, no warnings) the foundation on `m1/integration`: `TorontoCalendar`, `PrayerSlot`, `CheckInPhase`, `PrayerTimeline`, `Prayer+Display`, `OffsetClock`, `Core/History/*` (resolver, snapshots, streak calculator), `Config/Ruki-Info.plist`, portrait/iPhone-only build settings.
- CI now runs on `m1/**` pushes and gates on zero compiler warnings, plus a Release build (`scripts/check-no-warnings.sh`).
- **Not tested:** none of the new logic has unit tests yet (the stories add them). No M1 story is complete. Nothing from this session was run in CI; the local Debug build is the only verification.
- **Uncertain:** whether the cloud sandbox has `gh` authenticated and the PushNotification tool. The playbook stops safely and falls back to a GitHub mention if not.
- User asked for a text message; SMS isn't possible, so the alert is a Claude mobile push with a GitHub-mention fallback.

### 2026-09-20 — Session 7 (scheduled M1 routine, run 2)
Continued unattended per `docs/M1-PLAYBOOK.md`/D39. Checked for stale `in-progress` branches per the routine's own start-up rule first — found none (all 5 branches from run 1 were already `merged`) — so started clean at #17.

**Built, tested (CI, macOS/Xcode), and merged to `m1/integration`** — 6 branches, every one green on its **first** CI attempt (no fix-and-repush needed this run, unlike run 1):
- `m1/story-017-disable-fajr-independently` (#17): `UserSettings` + `PromptInputs`.
- `m1/story-015-background-refresh-horizon` (#15, **partial**): 12-day scheduling horizon + submit-only `BGTaskScheduler` wrapper, not yet wired to any trigger.
- `m1/task-app-shell` (T1): `AppEnvironment`/`AppRouter`/`RootView`/`RukiPalette`; removed the Xcode template `ContentView`.
- `m1/story-011-intention-screen` (#11): the niyyah/riya' onboarding screen.
- `m1/story-009-madhab-onboarding` (#9, **partial**): Asr madhab picker only — no calculation-method picker (D34) or 3-session profile (D31), by design.
- `m1/story-010-notification-permission` (#10): Time-Sensitive rationale screen + testable view model.

Full details (branch names, CI run URLs, per-story notes) are in `docs/M1-PROGRESS.md`, not duplicated here.

**One deliberate reordering, logged rather than silently done:** skipped #14 ("notification tap opens check-in") out of the playbook's listed order — it needs a check-in cover screen that doesn't exist until #19, much later, so building it now would mean inventing speculative router plumbing ahead of what #19 will actually need. Built #11 (self-contained, slots into the app shell's onboarding branch) instead. See `docs/M1-PROGRESS.md` Findings.

**No new Swift 6 concurrency surprises this run** — the two patterns logged in run 1 (non-`Sendable` `static let`, `@unchecked Sendable` for a class holding only an Apple singleton) were watched for proactively and avoided on the first attempt each time, including in new territory (`BGTaskScheduler`/`BGAppRefreshTaskRequest`, verified via web search before writing code rather than guessed).

**NOT tested:** any SwiftUI rendering, button wiring, or on-device behavior for the new App-shell/Onboarding views (no simulator in this sandbox); real `BGTaskScheduler` registration/delivery timing; real notification permission dialogs and Focus/DND piercing. `AppEnvironment.init()` itself has no dedicated test — flagged explicitly in `docs/M1-PROGRESS.md` as a real gap (assembling real singletons in a test host felt like low-value/flaky integration testing, not a meaningful unit test) rather than silently claimed as covered.

**Uncertain about:** whether `.backgroundTask(.appRefresh(_:))` (reasoned about via web search, Apple's own doc pages were blocked by the sandbox's egress proxy) is definitely the right registration approach once T2 wires an actual trigger, vs. the older manual `BGTaskScheduler.register`. Whether computing `AppEnvironment.timeline`/`backgroundRefresh` fresh on every access (rather than caching) is the right tradeoff long-term.

Stopped at 6 branches (playbook's stated cap). `m1/integration` green; `main` untouched — most stories are still `todo`, so the completion phase (playbook §5) does not apply yet.
