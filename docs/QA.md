# QA

Strategy and rationale: `PRD.md` §13. This file is the running record of what is actually covered and what is not. **If a gap isn't listed here, assume it isn't known** — add it.

## How to run

```sh
./scripts/check-no-date.sh          # no Date() outside SystemClock
xcodebuild test -project Ruki.xcodeproj -scheme Ruki \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RukiTests
./scripts/check-no-warnings.sh <xcodebuild.log>
```
CI (`.github/workflows/ci.yml`) runs, on Xcode 26.3 (pinned — see D40): the Date check, Debug build + unit tests, a Release build, and a **device-SDK build** (which compiles the real camera code the Simulator build replaces with a placeholder). Zero compiler warnings is enforced on all three builds.

## M1 verification — 2026-09-20 (Xcode 26.3, iOS Simulator 26.x)

| Level | Result |
|---|---|
| **L1 Static** | `check-no-date.sh` pass. No `fatalError`. Two `try!`/`as!`/`!` sites in shipping code, each with a why-comment (in-memory container fallback; `layerClass` cast; `Calendar` date arithmetic); one `.first!` inside a `#Preview` only. No networking (`URLSession`) anywhere. No location/coordinates. No analytics or third-party SDKs; **zero Swift packages**. Imports are Apple frameworks only. |
| **L2 Build** | Debug (Simulator), Release (Simulator) and Debug (**device SDK**, signing off) all succeed with **zero warnings**. |
| **L3 Unit tests** | **185 executions, 0 failures** (29 test files under `RukiTests/`), stable across repeated runs. |
| **L4 Time tests** | DST both directions, leap day, 366-day year sweep × 2 madhabs, Isha→Fajr across year rollover, Toronto-calendar day keys, planner horizon/64-cap, streak/pause overlap. All against the **frozen** provider — see gaps. |
| **L5 Values red-team** | See below. No release-blocking findings; several notes. |
| **L6 UI + accessibility** | **Not run.** XCUITest cannot complete on the development machine (launch hangs, `Mach error -308 server died` — same as M0) so `RukiUITests` stays excluded from CI (D29). Compensated by static checks: no `.red`, no `.left`/`.right`/`padding(.left…)` (RTL-safe), no fixed font sizes, every meaningful `Image` labelled or hidden, state carried by symbol + text, not colour. **No automated `performAccessibilityAudit()` exists.** |
| **L7 Code review** | Focused review of: friend payload, export/delete, notification scheduling, and the camera provider. Found and fixed 4 defects (below). **Not** a line-by-line review of all ~7,000 added lines. |
| **L8 Phone-only** | Not verifiable off-device. Checklist below. |

### Defects found during this verification (all fixed) — two independent passes
1. **CI toolchain mismatch.** CI defaulted to Xcode 16.4 (Swift 6.1); development is Xcode 26.3 (Swift 6.2). They disagree about actor isolation, so correct code failed CI and ~10 failure emails were sent chasing the wrong compiler. CI now pins 26.3.
2. **Flaky tests.** 5 `SettingsViewModelTests` slept 10 ms then asserted a fire-and-forget `Task` had run; they failed under load. Replaced with `waitUntil` polling and a barrier for the "does not refresh" cases. Stable over repeated runs.
3. **Delete could lie.** `deleteAllOnDeviceData()` swallowed errors and reset settings even if the wipe failed, telling the person their data was gone when it wasn't. It now returns `false`, changes nothing else, and Settings shows "Couldn't delete your data — nothing was removed." Tested.
4. **Camera, three latent bugs (device-only, never runnable in CI):** the live preview would have been **black on multi-cam iPhones** (multi-cam sessions need an explicit preview connection); every check-in after the first would **silently downgrade** to single-camera (graph re-wired on each start); and there was **no multi-cam format / hardware-cost check**. Fixed following Apple's AVMultiCamPiP pattern. **Unverified on hardware.**
5. **Photos were never purged (found by the routine's final session, missed by me).** `HistoryStore.purgeExpiredPhotos` (D37) existed but nothing called it, so photos were kept indefinitely. Now called from the launch/foreground/background refresh path. Tested.
6. **No way to resume a pause (same source).** PauseDurationView promised "you can turn it back on anytime" (RDP-3) but no control ended a pause. Added `resumeActivePause` and a one-tap resume on both pause entry points. Tested.
7. **Resuming left the open window stuck on "paused" (same source, caught by its own new test in CI).** `SlotResolver` treated any historical pause overlap as `.paused`. While a window is still open only a currently-active pause counts; the D38 overlap rule still protects a window once it closes. Tested.
8. Notification copy read like any adhan app ("Time for Asr."); now names the check-in (PRD R2c).

### L5 values red-team (PRD §4, CLAUDE.md domain rules)
- **Shame:** no red anywhere; no exclamation marks; copy says "no check-in", never "missed/failed"; late = "still counts". ✔
- **Absence leak (RDP-2):** the only serialisable friend-facing type is `FriendFacingCheckIn` — no pause, missed, or location field, enforced by tests (encoded keys + Mirror). No networking exists in M1, so nothing can leave the device at all. ✔
- **Pause leak (RDP-3):** same type/tests; pause lives only in `PauseRecord` and the local export. ✔
- **Camera during prayer (RDP-4):** the camera is reachable only via `CheckInViewModel.affirmPrayed()`, proven with a call-counting fake. ✔
- **Performance over practice (RDP-1):** the streak, rate and calendar are local views only. The one share surface is `ShareLink` on the user's **own data export** (check-ins, marks, pauses, no photos, no streak number). ✔
- **Location:** none (no permission, no CoreLocation, no field). ✔
- **Arbitration (RDP-6):** *known shortfall by design* — no 3-session/combining profile (D31), Jumu'ah treated as Dhuhr (D32), calculation method fixed and read-only (D34). Tracked, not hidden.
- **Server authority:** N/A in M1 — on-time is decided on-device from the injected clock; must be re-decided server-side in M2 (RDP/CLAUDE rule 6).
- **Third-party SDKs:** none.

## Known gaps — do not pretend these are covered

**Blocked on the real prayer engine (first item of M2):** everything runs on **one frozen September day** of Toronto times. The 366-day sweep proves the invariant's *shape*, not its *safety*; winter Maghrib, Fajr drift (3:30→6:00), solstices, and AlAdhan-fallback tolerance are untested. Full-year golden files (OQ-8) are the real fix.

**Needs a phone (checklist for the person testing):**
1. Camera permission prompt, and the denied path.
2. **First thing to check:** on a multi-cam iPhone, the live preview is visible (not black). Then a *second* check-in in the same app run still previews and captures both photos.
3. Dual capture returns front + rear; Space Only returns rear only; on a non-multi-cam iPhone (e.g. SE) the sequential path works.
4. Notification permission → prompt at adhan → tap opens the check-in for that prayer. Use Settings ▸ DEBUG: "send a test prompt in 10 s" and the clock-jump buttons; no need to wait for a real adhan.
5. **Time-Sensitive:** add the *Time Sensitive Notifications* capability (Xcode ▸ Signing & Capabilities) — until then notifications are ordinary and will not pierce Focus/DND (D36). Then verify it does.
6. Background refresh (Xcode ▸ Debug ▸ simulate the `com.salimsoufi.Ruki.refresh-prompts` task); force-quit, restart, Low Power, airplane mode, permission revoked mid-use.
7. Export opens the share sheet; "Delete my data" returns to onboarding.
8. VoiceOver through Today → check-in → history; Dynamic Type up to AX5 (**known:** history-grid cells are a fixed 20 pt); a right-to-left pseudo-language; Reduce Motion.
9. Prompt tap → posted in under 15 s (RUKI-019) — a timing target that only a device can measure.

**Not built (M2+):** server-authoritative timestamps, push + local dedup, sign-in (#8, deferred), friends/feed, account/server-side deletion. iPad is out of scope (D1).

**Product/fiqh, not code:** Isha's end (D30) and the Fajr window (D17) are check-in boundaries chosen to avoid refusing a valid prayer; they are not rulings. Scholar review (OQ-1) is a launch gate.

## Appendix — the routine's own completion pass (same day, run before this one was merged)

Kept for its detail; where it and the table above differ, the table above (verified locally on Xcode 26.3 and re-checked in CI) is authoritative.

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
`/ship-check` → runs `/time-check` and `/values-check`. A "yes" to any values question blocks the release.
