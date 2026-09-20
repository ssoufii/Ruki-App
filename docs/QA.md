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

### Defects found during this verification (all fixed)
1. **CI toolchain mismatch.** CI defaulted to Xcode 16.4 (Swift 6.1); development is Xcode 26.3 (Swift 6.2). They disagree about actor isolation, so correct code failed CI and ~10 failure emails were sent chasing the wrong compiler. CI now pins 26.3.
2. **Flaky tests.** 5 `SettingsViewModelTests` slept 10 ms then asserted a fire-and-forget `Task` had run; they failed under load. Replaced with `waitUntil` polling and a barrier for the "does not refresh" cases. Stable over repeated runs.
3. **Delete could lie.** `deleteAllOnDeviceData()` swallowed errors and reset settings even if the wipe failed, telling the person their data was gone when it wasn't. It now returns `false`, changes nothing else, and Settings shows "Couldn't delete your data — nothing was removed." Tested.
4. **Camera, three latent bugs (device-only, never runnable in CI):** the live preview would have been **black on multi-cam iPhones** (multi-cam sessions need an explicit preview connection); every check-in after the first would **silently downgrade** to single-camera (graph re-wired on each start); and there was **no multi-cam format / hardware-cost check**. Fixed following Apple's AVMultiCamPiP pattern. **Unverified on hardware.**
5. Notification copy read like any adhan app ("Time for Asr."); now names the check-in (PRD R2c).

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

## Release gate
`/ship-check` → runs `/time-check` and `/values-check`. A "yes" to any values question blocks the release.
