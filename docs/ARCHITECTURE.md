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
`PromptRefreshCoordinator` computes every slot from now through 12 calendar days out (`PrayerTimeline.slots(from:through:)`), drops whatever's already passed today, and hands the result to `PromptScheduler` — 12 × 5 = 60, under the 64 cap even with nothing disabled. `BackgroundRefreshScheduling`/`SystemBackgroundRefreshScheduler` wrap only the "ask for the next wake-up" half of `BGTaskScheduler` (`BGAppRefreshTaskRequest`/`submit`); registering the launch handler itself is SwiftUI's `.backgroundTask(.appRefresh(_:))` modifier on a `Scene`, not wrapped here. `BackgroundRefresh` ties the two into the one call a future launch handler makes. **Nothing calls this on a real trigger yet** (app launch, foreground, settings change, pause change) — those hooks belong to `T2` (Today screen) and RUKI-034 (pause); RUKI-015 is tracked `partial` for exactly this reason.

## App shell (`Ruki/App/`, `Ruki/DesignSystem/`)
`AppEnvironment` (`@MainActor`) is the composition root: builds every real `Core/` dependency exactly once (`OffsetClock` in DEBUG, `SystemClock` in Release; `SwiftDataPersistence`, falling back to an in-memory container rather than crashing if the persistent one can't open) and exposes `timeline`/`backgroundRefresh` as computed properties so they never read a stale madhab or enabled-prayers set. `AppRouter` reads `userSettings.onboardingCompletedAt` live to decide between the onboarding and main-flow branches — no separate state to keep in sync. `RootView` is the one view `RukiApp` shows; both branches are placeholders until their own stories (`RUKI-011`, `T2`) build real screens. `RukiPalette` (`DesignSystem/`) defines only base tokens (background/surface/text/accent) — deliberately no red anywhere, and no on-time/late/missed/paused semantics, which belong to the calendar screen (RUKI-032) and must carry state through shape and label, not colour alone.

## Deliberate limitations
- **`FixedPrayerTimeProvider` is one captured day (2026-09-19, approximate ISNA) reused for every date.** It must not reach anyone but the builder. The real engine is the first item of M2.
- `Prayer` has five cases; Jumu'ah is not an engine case (D32). 3-session combining is not modelled (D31).
- `RootView`'s two branches (onboarding, today) are placeholders — no real screen exists yet, and no backend.
- Notification/background-refresh scheduling has a caller (`AppEnvironment.backgroundRefresh`) but nothing invokes it on a real trigger yet (app launch, background refresh, foreground, settings change, pause change). That wiring is `T2` (Today screen) and RUKI-034 (pause).
