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

## Release gate

`/ship-check` → runs `/time-check` and `/values-check`. A "yes" to any values question (can this shame a user, leak an absence or a pause, reward performance over practice) blocks the release.
