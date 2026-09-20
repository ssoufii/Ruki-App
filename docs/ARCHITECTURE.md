# Architecture — what is actually built

Planned architecture is in `PRD.md` §10. This file records what exists. Last updated 2026-09-20 (M1 in progress).

## Project settings (D28)
Xcode 16+ file-system synchronized groups — dropping a `.swift` file in a folder adds it to the target; never hand-edit `project.pbxproj`. iOS 17.0 minimum, Swift 6 language mode, default actor isolation `nonisolated`. Core types are therefore callable from background contexts without annotation; add `@MainActor` to the specific type that needs it.

## Core (`Ruki/Core/`)
Every external dependency sits behind a protocol with a test fake in `RukiTests/TestSupport/`.

| Boundary | Real implementation | Fake |
|---|---|---|
| `ClockProviding` | `SystemClock` — **the only place `Date()` may be called** (enforced by `scripts/check-no-date.sh` in CI) | `FixedClock` |
| `PrayerTimeProviding` | `FixedPrayerTimeProvider` (D27) | `StubPrayerTimeProvider` |
| `NotificationScheduling` | `UserNotificationScheduler` (wraps `UNUserNotificationCenter`) | `FakeNotificationScheduler` |
| `NotificationAuthorizing` | `SystemNotificationAuthorizer` | `FakeNotificationAuthorizer` |
| `PersistenceProviding` | `SwiftDataPersistence` | `FakePersistenceProvider` |
| `CameraProviding` | none yet (M1, UIKit) | `FakeCameraProvider` |

## Prayer windows
`PrayerTimeProviding.prayerWindows(for:madhab:)` returns five `PrayerWindow`s for the Toronto calendar day: `start` (adhan, when the prompt fires), `checkInWindowEnd` (on-time cutoff), `end` (prayer window close; a check-in between the two is Late).

| Prayer | checkInWindowEnd | end |
|---|---|---|
| Fajr | = end (Option A, D17) | sunrise |
| Dhuhr / Asr / Isha | start + 30 min | next prayer's start; Isha → **next day's Fajr** (D30) |
| Maghrib | start + 20 min (D16) | Isha's start |

**Invariant** (`PrayerWindow.satisfiesCheckInWindowInvariant`): `checkInWindowEnd > start`; strictly `< end` for every prayer except Fajr; exactly `== end` for Fajr. This deliberately replaced an earlier `<=`-for-all check that could not tell Fajr's intentional equality from a bug elsewhere.

## On-device history (`Ruki/Core/Persistence/`, `Ruki/Core/History/`)
`CheckInRecord`/`PrayerMark`/`PauseRecord` are `@Model` SwiftData types with raw-`String` enum fields (so a future case rename doesn't force a migration). `HistoryStore` (`@MainActor`, wraps a `ModelContext`) is the only thing that touches them; everywhere else works with the value-type snapshots (`CheckInSnapshot`/`MarkSnapshot`/`PauseSnapshot`) that `SlotResolver` and `StreakCalculator` consume. One check-in/mark per slot — a second write upserts rather than duplicating. Photos (`frontImageData`/`rearImageData`) are dropped by `HistoryStore.purgeExpiredPhotos` once `expiresAt` (the next prayer's start) passes; the record itself is kept forever (D26/D37). `StreakSummaryPresenter` turns a `StreakSummary` into the profile's copy, including the forward-looking reset line.

## Notification scheduling (`Ruki/Core/Notifications/`)
`PromptPlanner` is pure: given slots and the set of enabled prayers, it produces `PromptSpec`s (id prefixed `ruki.prompt.`, capped at 64 — RUKI-016) sorted by fire date. `PromptScheduler` plans then calls `NotificationScheduling.replacePending(with:soundEnabled:)`, which is idempotent (a caller never diffs against what's already pending) and throws `NotificationSchedulingError.tooManyPending` as a second line of defense above the cap. `UserNotificationScheduler` is the real implementation: a `UNCalendarNotificationTrigger` built from components in `America/Toronto` (so the fire time is the Toronto adhan regardless of the device's own zone), `.timeSensitive` interruption level. `SystemNotificationAuthorizer` wraps the permission surface (`NotificationAuthorizing`). Both real types are `@unchecked Sendable`: `UNUserNotificationCenter` isn't an audited-`Sendable` Apple type, but both hold nothing except the shared `.current()` singleton.

## Settings (`Ruki/Core/Settings/`)
`UserSettings` (`@MainActor`, `UserDefaults`-backed) is the single source of truth for madhab, check-in window length, per-prayer enable/disable (RUKI-017 — stored as the *disabled* complement so a fresh install reads back as "everything enabled"), sound, Space Only default, and onboarding completion. `PromptInputs` (`Core/Notifications/`) is the `Sendable` snapshot of the fields that affect scheduling, so the `@MainActor`-isolated `UserSettings` itself never has to cross an actor boundary.

## Friend-facing payload (`Ruki/Core/Networking/`)
`FriendFacingCheckIn` is the only shape a friend is ever allowed to read (PRD §10.3) — no `pausedUntil`, no missed-prayer field, no location. Tested by checking both the encoded JSON's keys and the type's own `Mirror` against a denylist, so a future field addition here has to clear the same bar. There is no networking layer yet (M2) — this type exists so the boundary is enforced before there's a server to send it to.

## 12-day horizon and background refresh (`Ruki/Core/Notifications/`)
`PromptRefreshCoordinator` computes every slot from now through 12 calendar days out (`PrayerTimeline.slots(from:through:)`), drops whatever's already passed today, and hands the result to `PromptScheduler` — 12 × 5 = 60, under the 64 cap even with nothing disabled. `BackgroundRefreshScheduling`/`SystemBackgroundRefreshScheduler` wrap only the "ask for the next wake-up" half of `BGTaskScheduler` (`BGAppRefreshTaskRequest`/`submit`); registering the launch handler itself is SwiftUI's `.backgroundTask(.appRefresh(_:))` modifier, wired on `RukiApp` (T2). `AppEnvironment.refreshBackgroundSchedule()` wraps that call; `RukiApp` uses it on launch (`.task`), on returning to the foreground (`.onChange(of: scenePhase)`), and as the background-task handler, and `TodayView`'s pause flow (RUKI-034) calls the same method right after recording a pause. **Only the settings-change trigger is still missing** — that hook belongs to RUKI-036, not yet built; RUKI-015 stays `partial` for that one remaining case.

## App shell (`Ruki/App/`, `Ruki/DesignSystem/`)
`AppEnvironment` (`@MainActor`) is the composition root: builds every real `Core/` dependency exactly once (`OffsetClock` in DEBUG, `SystemClock` in Release; `SwiftDataPersistence`, falling back to an in-memory container rather than crashing if the persistent one can't open) and exposes `timeline`/`backgroundRefresh` as computed properties so they never read a stale madhab or enabled-prayers set. `AppRouter` reads `userSettings.onboardingCompletedAt` live to decide between the onboarding and main-flow branches — no separate state to keep in sync. `RootView` routes to `OnboardingFlow` (RUKI-011) or `TodayView` (T2) — both real screens now. `RukiApp` also registers the `.backgroundTask(.appRefresh(_:))` launch handler and drives the launch/foreground refresh calls described above. `RukiPalette` (`DesignSystem/`) defines only base tokens (background/surface/text/accent) — deliberately no red anywhere, and no on-time/late/missed/paused semantics, which belong to the calendar screen (RUKI-032) and must carry state through shape and label, not colour alone. `ComingSoonScreen` (`DesignSystem/`) is the shared honest-placeholder view for a destination whose own story hasn't landed yet.

## Today screen (`Ruki/Features/Today/`, T2)
`TodayViewModel` (`@MainActor @Observable`) computes today's five prayer rows, a current/next-prayer headline with a gentle countdown, and which row (if any) is open right now — everything derived from `clock.now()`, `PrayerTimeline`, `UserSettings`, and a `SlotResolver` built from `HistoryStore`'s snapshots. `refresh()` is called on appear and every 60 seconds (`TodayView`'s `Timer.publish` tick only triggers a re-read of `clock.now()`; it never stands in for it). Each row's `Status` carries a paired label + SF Symbol — never colour alone. Checking in is still a doorway (`ComingSoonScreen`) until a real `CameraProviding` exists (RUKI-020). Tapping a `.missed` row (a closed window with no check-in) opens `MissedPrayerMarkView` (RUKI-026) — "I prayed" or "I didn't", on-device only via `HistoryStore.recordMark`, never a network event either way (RDP-2). `TodayViewModel.mark(_:as:)` writes the mark and refreshes.

## Pause (`Ruki/Features/Pause/`, RUKI-034)
Two taps, no reason field: "Pause check-ins" on `TodayView` opens `PauseDurationView`, and picking one of `PauseDuration`'s five cases (today/3/7/10 days/until resumed) pauses immediately — no confirmation step. `PauseDuration.endsAt(from:)` is pure and tested on its own; `.today` ends at the start of tomorrow (Toronto) rather than exactly 24h later, so it can't leak past the calendar day regardless of what time it's tapped. `TodayViewModel.pause(for:)` calls `HistoryStore.recordPause` and refreshes; `TodayView` then calls `onPauseChanged` (wired by `RootView` to `AppEnvironment.refreshBackgroundSchedule()`) so notifications stop firing for the paused window. Only the tap-based entry point exists — PRD §7.8's alternate long-press-on-the-main-action entry isn't built.

## Check-in flow (`Ruki/Features/CheckIn/`, RUKI-019)
`CheckInViewModel` (`@MainActor @Observable`) is the affirm → capturing → review → posted/failed state machine. `affirmPrayed()` is the only path that ever calls `CameraProviding` — nothing reaches the camera before the user affirms (RDP-4), and the RUKI-019 test suite asserts this with a call-counting fake (`RecordingCameraProvider`) rather than relying on code structure alone. Posting is immediate: `post()` calls `HistoryStore.recordCheckIn` and moves straight to `.posted`, with no draft state to discard. `isLate` and `expiresAt` are computed by the caller (from `PrayerTimeline.phase`/`nextSlot`) and passed in — the view model has no notion of "now" beyond the `ClockProviding` it's given. `CheckInRules.sanitizedCaption` (RUKI-023) trims and caps the optional caption at 80 characters — applied once, at `post()`, not while typing — and `CheckInRecord`/`HistoryStore.recordCheckIn` carry it through to match PRD §10.3's `CheckIn.caption?`. **Not yet reachable from `TodayView`:** there's no real `CameraProviding` implementation to inject (RUKI-020's Simulator placeholder and `AVCameraProvider` don't exist yet), so wiring this in now would mean shipping a test fake into a real screen. `CheckInFlowView`'s own `#Preview` uses a private, preview-only fake for the same reason `RukiTests`' fakes aren't visible to app-target previews.

## Onboarding (`Ruki/Features/Onboarding/`)
`OnboardingFlow` sequences madhab (RUKI-009, partial) → notification permission (RUKI-010) → intention (RUKI-011) → add-friends (RUKI-012), matching PRD §7.1. `AddFriendsView` is the only screen that mentions friends anywhere in M1 — there is no add-friend mechanism yet (Circle is M2), so its "Add friends" button opens `ComingSoonScreen` and "Skip for now" is the one fully-working path; onboarding always completes with zero friends. `RukiTests/Integration/SoloFlowTests.swift` proves the prompt/capture-recording/streak/history flow works end-to-end for a fresh solo account and that the types it touches (`PromptInputs`, `CheckInSnapshot`) carry no friend/circle field.

## Deliberate limitations
- **`FixedPrayerTimeProvider` is one captured day (2026-09-19, approximate ISNA) reused for every date.** It must not reach anyone but the builder. The real engine is the first item of M2.
- `Prayer` has five cases; Jumu'ah is not an engine case (D32). 3-session combining is not modelled (D31).
- `TodayView`'s check-in button still opens `ComingSoonScreen` — no real capture flow exists yet (RUKI-020's camera implementation). Pause (RUKI-034) is real.
- Background-refresh scheduling runs on app launch, foreground, and pause change (`RukiApp`, T2; `TodayView`'s pause flow, RUKI-034) but still has no settings-change trigger (RUKI-036).
