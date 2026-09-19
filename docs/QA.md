# QA

Strategy and rationale: `PRD.md` §13. This file is the running record of what is actually covered and what is not. **If a gap isn't listed here, assume it isn't known** — add it.

## How to run

```sh
./scripts/check-no-date.sh          # no Date() outside SystemClock
xcodebuild test -project Ruki.xcodeproj -scheme Ruki \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RukiTests
```
CI (`.github/workflows/ci.yml`) runs both on every PR and push to `main`.

## What is covered (as of 2026-09-19)

15 test executions, 13 test functions (parameterized tests run once per argument; Xcode reports both numbers). All against `FixedPrayerTimeProvider`.

| Suite | Covers |
|---|---|
| `Core/PrayerTimes/FixedPrayerTimeProviderTests` | Check-in invariant on the reference day, Fajr adhan→sunrise (Option A), Maghrib = 20 min, Hanafi Asr later than Standard, window ordering, wall-clock stability |
| `TimeEdgeCases/FixedProviderTimeEdgeCaseTests` | Invariant on all 366 days × both madhabs; wall-clock times across both 2026–27 DST transitions; leap day (2028-02-29); Isha ends at next Fajr incl. year rollover (D30); the invariant rejects zero-Late-phase, overrun, and clamped-Fajr windows |
| Static | `scripts/check-no-date.sh` |

Builds verified: Debug (simulator, from clean DerivedData) and Release (simulator), zero compiler warnings.

## Known gaps — do not pretend these are covered

**Blocked on the real prayer engine (Epic 13, first item of M2):**
- The fixed provider returns *identical* wall-clock times every day, so the 366-day sweep proves the invariant's *shape*, not its *safety*. It cannot catch Maghrib's window shrinking in winter, Fajr swinging 3:30→6:00, or Isha drifting past 10 p.m. Real coverage = full-year golden files × 2 madhabs against the chosen timetable (OQ-8).
- Solstices and equinoxes.
- AlAdhan-unavailable → Adhan-Swift fallback tolerance.
- DST *boundary* behaviour of notification scheduling (the fixed times all fall after 2 a.m., so the 2 a.m. jump never touches them; the March case that lands near a real Fajr is untested).

**Not yet built, so untested (M1+):** notification delivery matrix (foreground/background/force-quit/restart/Low Power/Focus/DND/permission revoked/airplane/64-cap/push+local dedup); device clock tampering and server-authoritative timestamps; camera and permission-denied paths; storage full; streak and pause logic; RDP-2/RDP-3 payload leakage.

**Not testable in this environment:** physical devices (multi-cam fallback, real Time-Sensitive delivery). `RukiUITests` is still Xcode's empty template and is excluded from CI (D29).

**Accessibility / RTL:** nothing to test yet — no UI. Do it as screens land, not after.

**Product/fiqh, not code:** Isha's end (D30) and the Fajr window (D17) are check-in boundaries chosen to avoid refusing a valid prayer; they are not rulings. Scholar review (OQ-1) is a launch gate.

## Release gate

`/ship-check` → runs `/time-check` and `/values-check`. A "yes" to any values question (can this shame a user, leak an absence or a pause, reward performance over practice) blocks the release.
