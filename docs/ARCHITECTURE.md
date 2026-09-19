# Architecture — what is actually built

Planned architecture is in `PRD.md` §10. This file records what exists. Last updated 2026-09-19 (end of M0).

## Project settings (D28)
Xcode 16+ file-system synchronized groups — dropping a `.swift` file in a folder adds it to the target; never hand-edit `project.pbxproj`. iOS 17.0 minimum, Swift 6 language mode, default actor isolation `nonisolated`. Core types are therefore callable from background contexts without annotation; add `@MainActor` to the specific type that needs it.

## Core (`Ruki/Core/`)
Every external dependency sits behind a protocol with a test fake in `RukiTests/TestSupport/`.

| Boundary | Real implementation | Fake |
|---|---|---|
| `ClockProviding` | `SystemClock` — **the only place `Date()` may be called** (enforced by `scripts/check-no-date.sh` in CI) | `FixedClock` |
| `PrayerTimeProviding` | `FixedPrayerTimeProvider` (D27) | `StubPrayerTimeProvider` |
| `NotificationScheduling` | none yet (M1) | `FakeNotificationScheduler` |
| `PersistenceProviding` | none yet (M1, SwiftData) | `FakePersistenceProvider` |
| `CameraProviding` | none yet (M1, UIKit) | `FakeCameraProvider` |

## Prayer windows
`PrayerTimeProviding.prayerWindows(for:madhab:)` returns five `PrayerWindow`s for the Toronto calendar day: `start` (adhan, when the prompt fires), `checkInWindowEnd` (on-time cutoff), `end` (prayer window close; a check-in between the two is Late).

| Prayer | checkInWindowEnd | end |
|---|---|---|
| Fajr | = end (Option A, D17) | sunrise |
| Dhuhr / Asr / Isha | start + 30 min | next prayer's start; Isha → **next day's Fajr** (D30) |
| Maghrib | start + 20 min (D16) | Isha's start |

**Invariant** (`PrayerWindow.satisfiesCheckInWindowInvariant`): `checkInWindowEnd > start`; strictly `< end` for every prayer except Fajr; exactly `== end` for Fajr. This deliberately replaced an earlier `<=`-for-all check that could not tell Fajr's intentional equality from a bug elsewhere.

## Deliberate limitations
- **`FixedPrayerTimeProvider` is one captured day (2026-09-19, approximate ISNA) reused for every date.** It must not reach anyone but the builder. The real engine is the first item of M2.
- `Prayer` has five cases; Jumu'ah is not an engine case (D32). 3-session combining is not modelled (D31).
- `ContentView` is still the Xcode template. There is no UI, backend, or persistence.
