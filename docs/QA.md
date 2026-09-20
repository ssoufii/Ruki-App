# QA

Strategy and rationale: `PRD.md` §13. This file is the running record of what is actually covered and what is not. **If a gap isn't listed here, assume it isn't known** — add it.

## How to run

```sh
./scripts/check-no-date.sh          # no Date() outside SystemClock
xcodebuild test -project Ruki.xcodeproj -scheme Ruki \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RukiTests
```
CI (`.github/workflows/ci.yml`) runs both on every PR and push to `main`.

## What is covered (as of 2026-09-20, M1 routine run)

All against `FixedPrayerTimeProvider` unless noted; all run in CI on GitHub Actions (macOS-15, Xcode 16.4).

| Suite | Covers |
|---|---|
| `Core/PrayerTimes/FixedPrayerTimeProviderTests` | Check-in invariant on the reference day, Fajr adhan→sunrise (Option A), Maghrib = 20 min, Hanafi Asr later than Standard, window ordering, wall-clock stability |
| `Core/PrayerTimes/PrayerTimelineTests` | Fajr's `onTimeEnd` ignores the user check-in-window setting (D33); Fajr never reaches `.late` across a 5-minute sweep of its whole window; onTime/closed boundary at sunrise; non-Fajr prayers do honour the setting and do reach `.late` |
| `TimeEdgeCases/FixedProviderTimeEdgeCaseTests` | Invariant on all 366 days × both madhabs; wall-clock times across both 2026–27 DST transitions; leap day (2028-02-29); Isha ends at next Fajr incl. year rollover (D30); the invariant rejects zero-Late-phase, overrun, and clamped-Fajr windows |
| `Core/History/StreakCalculatorTests` | Streak counted in prayers not days (D25); late counts identically to on-time; privately-marked-prayed counts; a miss resets current but not lifetime; a paused slot is skipped (freezes, doesn't break); 30-day on-time rate incl. the 30-day cutoff and the nil-until-settled case |
| `Core/History/SlotResolverTests` | Precedence check-in > mark > pause-overlap > pending/missed; `notTracked` before install; D38 pause-overlap rule incl. mid-window start and open-ended (`endsAt == nil`) pauses; a pause ending before the window starts does not protect it |
| `Core/History/StreakSummaryPresenterTests` | Reset headline is forward-looking and names the next Fajr time, never "missed"/"failed"; lifetime and 30-day-rate text survive a reset |
| `Core/Persistence/HistoryStoreTests` | SwiftData round-trip for check-ins/marks/pauses against an in-memory `RukiModelContainer`; one check-in/mark per slot (upsert, not duplicate); `purgeExpiredPhotos` clears photo data at `expiresAt` while the record survives (D26/D37) |
| `Core/Networking/FriendFacingCheckInTests` | Encoded-JSON keys and `Mirror` reflection both checked against a pause/missed/location denylist (RUKI-035, RDP-2/3, D8); Codable round-trip |
| `Core/Notifications/PromptPlannerTests` | One spec per slot firing at adhan; `ruki.prompt.` id prefix; disabled prayers excluded; specs sorted by fire date; caps at 64 keeping the earliest-firing notifications (RUKI-016) |
| `Core/Notifications/PromptSchedulerTests` / `NotificationSchedulingCeilingTests` | `refresh` plans then hands the exact result to the scheduler; honours per-prayer enable/disable; a second `refresh` replaces rather than accumulates; the scheduler itself throws above 64 as a second line of defense; exactly 64 is accepted |
| Static | `scripts/check-no-date.sh` |

Builds verified in CI: Debug (simulator) and Release (simulator), zero compiler warnings, on every push to `m1/**`.

## Known gaps — do not pretend these are covered

**Blocked on the real prayer engine (Epic 13, first item of M2):**
- The fixed provider returns *identical* wall-clock times every day, so the 366-day sweep proves the invariant's *shape*, not its *safety*. It cannot catch Maghrib's window shrinking in winter, Fajr swinging 3:30→6:00, or Isha drifting past 10 p.m. Real coverage = full-year golden files × 2 madhabs against the chosen timetable (OQ-8).
- Solstices and equinoxes.
- AlAdhan-unavailable → Adhan-Swift fallback tolerance.
- DST *boundary* behaviour of notification scheduling (the fixed times all fall after 2 a.m., so the 2 a.m. jump never touches them; the March case that lands near a real Fajr is untested).

**Not yet built, so untested (M1+):** notification delivery matrix (foreground/background/force-quit/restart/Low Power/Focus/DND/permission revoked/airplane/push+local dedup — the 64-cap itself is now unit-tested at the planner/scheduler level, see above); device clock tampering and server-authoritative timestamps; camera and permission-denied paths; storage full. Streak/pause logic and RDP-2/RDP-3 payload leakage are now unit-tested (see above) but only at the logic level — no UI exists yet to verify the tone rules render correctly on screen.

**Notification scheduling specifically (RUKI-013/016, landed 2026-09-20):** `PromptPlanner`/`PromptScheduler`/`NotificationSchedulingError` are unit-tested against `FakeNotificationScheduler`. `UserNotificationScheduler` (the real `UNUserNotificationCenter` wrapper) and `SystemNotificationAuthorizer` compile and are exercised only through the protocol/fake in tests — real calendar-trigger firing, `.timeSensitive` actually piercing Focus/DND, and permission-prompt behavior are unverified and can only be checked on a physical device once the Time Sensitive Notifications capability is added in Xcode (D36).

**Not testable in this environment:** physical devices (multi-cam fallback, real Time-Sensitive delivery). `RukiUITests` is still Xcode's empty template and is excluded from CI (D29).

**Accessibility / RTL:** nothing to test yet — no UI. Do it as screens land, not after.

**Product/fiqh, not code:** Isha's end (D30) and the Fajr window (D17) are check-in boundaries chosen to avoid refusing a valid prayer; they are not rulings. Scholar review (OQ-1) is a launch gate.

## M1 completion verification (docs/M1-PLAYBOOK.md §5), 2026-09-20

### L1 — Static

- `scripts/check-no-date.sh`: pass.
- `fatalError`: none in `Ruki/` (one mention, in a doc comment explaining why it's avoided).
- `print(`: none in `Ruki/`.
- Force unwraps (`!`) and `try!` outside tests: 7 found, all with a why-comment already present except one (`CheckInFlowView`'s `#Preview`), which got one added as part of this pass.
- Location/coordinate fields: none. No `latitude`/`longitude`/`CLLocation`/`coordinate` anywhere in `Ruki/`, and `Config/Ruki-Info.plist` has no location usage-description key (PRD §11.2, D8, D21).
- Third-party/analytics SDK imports: none — every `import` in `Ruki/` is a first-party Apple framework (`AVFoundation`, `BackgroundTasks`, `Combine`, `Foundation`, `Observation`, `SwiftData`, `SwiftUI`, `UIKit`, `UserNotifications`, `os`).

### L2/L3 — Build and unit tests

Verified in CI on `m1/final-verification`: see the Run log entry in `docs/M1-PROGRESS.md` for the exact CI run URL. Debug build, `RukiTests`, and Release build all green with zero compiler warnings (same gate as every story branch all along).

### L4 — Time tests

Covered by the existing suites in the table above (`TimeEdgeCases`, `PrayerTimelineTests`, `PromptPlannerTests`/`PromptSchedulerTests` for the 64-cap and DST-adjacent planning). **One real, known gap, not closed by this pass:** CLAUDE.md calls full-year golden-file tests against a reference timetable "non-negotiable," but `RukiTests/GoldenFiles/` does not exist — there is no full-year comparison against an authoritative external Toronto prayer-time calendar. This is the same gap already tracked above under "Blocked on the real prayer engine" (OQ-8): `FixedPrayerTimeProvider` returns identical wall-clock times every day, so there is no real seasonal data to build a golden file from yet, and fabricating a "reference timetable" without a real, chosen source would be worse than not having one — OQ-8 has to resolve first (tracked as blocking M2, per D27). Not fixed in this pass; flagged here explicitly rather than left implicit.

### L5 — Values red-team (`.claude/commands/values-check.md`)

1. **Shame** — NO. Grepped every user-facing string for "fail"/"missed" language; the only "missed"-adjacent copy is `SlotOutcome.calendarLabel`'s `.missed → "No check-in"` (`Ruki/Core/History/SlotOutcome+Display.swift`), neutral by design. `RukiPalette` (`Ruki/DesignSystem/RukiPalette.swift`) defines no red anywhere, and its own doc comment states that's deliberate. `MissedPrayerMarkView`, `StreakSummaryPresenter`, and `CheckInViewModel.postedMessage` all carry explicit "no red, no FAILED" doc comments backed by tests (`StreakSummaryPresenterTests`, `CheckInViewModelTests.lateCopyStaysWarm`).
2. **Absence leak (RDP-2)** — NOT APPLICABLE YET. M1 has no networking layer at all (`grep -rl "URLSession\|URLRequest" Ruki/` is empty, `server/` doesn't exist) — nothing leaves the device in M1, so there is no channel for an absence to leak through yet. `FriendFacingCheckIn` (`Ruki/Core/Networking/FriendFacingCheckIn.swift`) is the payload *shape* M2's networking will eventually send, and it only ever represents a posted check-in (no "gap" event type exists); `FriendFacingCheckInTests` denylists pause/missed/location keys against both the encoded JSON and a `Mirror` reflection. Re-run this question for real once M2 adds an actual send path.
3. **Pause leak (RDP-3)** — NO. Same payload type, same denylist tests; `pausedUntil`/`paused`/`isPaused`/`pauseState`/`pauseRecord` are all in `FriendFacingCheckInTests.forbiddenKeys` and none exist on `FriendFacingCheckIn`'s stored properties.
4. **Camera during prayer (RDP-4)** — NO. `CheckInViewModel.affirmPrayed()` (`Ruki/Features/CheckIn/CheckInViewModel.swift`) is the only method that calls `cameraProvider.requestAuthorization()`/`startSession()`; `CheckInViewModelTests.cameraUnreachableBeforeAffirming` asserts the capture recorder's call count is 0 before affirming.
5. **Performance over practice (RDP-1)** — NO. No leaderboard/ranking/public-count code exists. The one `ShareLink` in the app (`Ruki/Features/Settings/SettingsView.swift`) is the user exporting their *own* JSON data (RUKI-037), not a social share. Onboarding copy (`IntentionView`, `AddFriendsView`) explicitly commits to "never a ranking, never a count," matching D24 (streak visible only to the user, no sharing mechanism at all).
6. **Location** — NO. See L1 above.
7. **Arbitration (RDP-6)** — NO outright violation. `MadhabSelectionView` presents both Asr conventions neutrally ("Choose which convention you follow"). Known v1 shortfalls are documented, not silent: the 3-session/Shia-combining profile is out of scope for v1 (D31, `MadhabSelectionView`'s own doc comment cites it), and Jumu'ah is handled as plain Friday Dhuhr with the data model reserving `jumuah` for the fast-follow (D32, `Ruki/Core/PrayerTimes/Prayer.swift`).
8. **Server authority** — **YES, on-time status is decided by the device clock everywhere** (`ClockProviding`/`clock.now()`), because **M1 has no server at all** (same scope boundary as Q2). Flagging this precisely rather than answering NO: CLAUDE.md rule 6 exists to stop a device clock from being trusted for an *adversarial, multi-party* determination (a friend seeing "on time" they can't verify) — that scenario doesn't exist yet in M1, since `isLate` is a private, personal fact used only for local streak math and this device's own copy, never transmitted or shown to anyone else (see Q2/Q3). Judged **not a release blocker for M1's solo-loop scope**, but this is a call the PM/user should see stated plainly rather than have silently marked "NO" — it becomes a real, must-fix-before-ship item the moment M2 puts `isLate`/on-time status in front of another person.
9. **Third-party SDKs / analytics** — NO. See L1 above.

**Verdict: CLEAR-FOR-WHAT-EXISTS.** No YES on 1, 3, 4, 5, 6, 7, or 9. Q2 is not-yet-applicable (no network layer exists). Q8 is a YES by the literal question, but scoped to a milestone where the underlying trust concern doesn't yet apply (see above) — carried forward as a hard requirement for M2, not waived.

### L6 — UI + accessibility

See the Run log entry in `docs/M1-PROGRESS.md` for whether the new `RukiUITests` smoke suite (onboarding → Today → check-in → History, plus `performAccessibilityAudit()`) passed reliably on CI and was kept, or came back out per D29.

### L7 — Independent code review

Full diff `main...m1/integration` was small by the time this ran (the repo owner had already PR-merged most of M1 story-by-story into `main` during development) — instead, a fresh subagent reviewed the actual `Ruki/` source tree for correctness, concurrency, and privacy issues, independent of the sessions that wrote it. See the Run log entry in `docs/M1-PROGRESS.md` for what it found and fixed.

### L8 — Phone-only (cannot automate here — listed, not gated)

- Real dual-camera capture and the automatic sequential fallback, on actual hardware (multi-cam vs. pre-A12 devices).
- Real `UNUserNotificationCenter` delivery: Time-Sensitive actually piercing Focus/DND (needs the Time Sensitive Notifications capability added in Xcode by someone with access to the Apple Developer team, D36), permission-prompt behavior, push+local dedup.
- Real `BGTaskScheduler` background-refresh timing and delivery.
- The JSON export file's actual `ShareLink` share-sheet behavior.
- RTL layout and VoiceOver, beyond what `performAccessibilityAudit()` covers in the Simulator.

## Release gate

`/ship-check` → runs `/time-check` and `/values-check`. A "yes" to any values question (can this shame a user, leak an absence or a pause, reward performance over practice) blocks the release.
