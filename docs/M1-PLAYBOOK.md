# M1 Playbook — instructions for the unattended M1 routine

You are the "M1 routine": a scheduled cloud agent that builds Milestone 1 (solo loop) of Ruki one story at a time. You start every run with **zero memory**. This file plus `docs/M1-PROGRESS.md` are your memory. Read this file fully at the start of every run.

## 0. Read first, every run
1. `CLAUDE.md`, `MEMORY.md` (decision log — do not contradict it), `PRD.md` §4, §7, §9, §10, `docs/ARCHITECTURE.md`, `docs/QA.md`.
2. `docs/M1-PROGRESS.md` — which stories are done, blocked, or next.
3. Check out `m1/integration` and `git pull`. **Never commit to `main` except in §5.**

## 1. What you can and cannot do in this sandbox
- The sandbox is **Linux. There is no Xcode, no Swift iOS toolchain, no simulator.** You cannot compile or run the app. **GitHub Actions (macOS) is your compiler and test runner.** Write Swift conservatively: Swift 6 strict concurrency, no clever code, match surrounding style, one type per file, `// MARK:` in files over ~100 lines, comments explain *why*.
- Run `gh auth status` first. If `gh` is unavailable or unauthenticated you cannot see CI: **do not merge anything**, record `blocker: no CI visibility` in the progress file, send the alert in §6 saying so, and stop.
- Use `./scripts/check-no-date.sh` locally (it's plain bash) before every push.
- Never edit `project.pbxproj` (the source folders are file-system synchronized; new `.swift` files build automatically). Never force-push. Never touch `main` outside §5. No secrets in commits.

## 2. Per-story procedure (repeat for up to 6 stories per run, then stop)
1. Pick the first story in §4 whose status in `docs/M1-PROGRESS.md` is `todo` and whose dependencies are `merged`. Read its GitHub issue (`gh issue view N`) for the acceptance criteria.
2. `git checkout m1/integration && git pull && git checkout -b m1/story-NNN-short-slug` (supporting tasks: `m1/task-slug`). **One new branch per story.**
3. Implement it **with tests in the same change** (Swift Testing, `RukiTests/`, mirroring the source layout). Golden rule from CLAUDE.md: never call `Date()` outside `SystemClock`; inject `ClockProviding`. Every external dependency behind a protocol with a fake. User-facing strings via String Catalog / `String(localized:)`. Accessibility labels, Dynamic Type, no colour-only meaning, leading/trailing not left/right.
4. Tone rules (CLAUDE.md "Tone"): warm, never scolding; no red, no "FAILED"; late = "Checked in late — still counts."
5. `./scripts/check-no-date.sh`, commit (message ends with the attribution lines from the session's git instructions; include `Refs #N`, **not** `Closes`), `git push -u origin <branch>`.
6. **Wait for CI on that branch**: `gh run list --branch <branch> --limit 1`, then `gh run watch <id> --exit-status` (poll; ~5 min). CI = Debug build + unit tests + Release build, zero compiler warnings.
7. **Green →** `git checkout m1/integration && git merge --no-ff <branch> && git push`, update the progress file (status `merged`, branch name, CI run URL, one line on what was and wasn't tested), push. Close the issue with `gh issue close N --comment "<what was built / tested / not tested>"` **only if the story is fully satisfied**; if partial, comment and leave it open (status `partial`).
8. **Red →** read the log (`gh run view <id> --log-failed`), fix on the same branch, push, re-wait. Max 3 attempts. If still red: status `blocked` with the reason, do **not** merge, do **not** start any story that depends on it, continue with independent stories.
- If a run is taking long, stop cleanly after the current story. Always leave `m1/integration` green and the progress file accurate.

## 3. Honesty rules
- Never mark something tested that CI didn't run. Never describe camera or notification *delivery* as working — they cannot be verified in CI; say "compiles, unit-tested at the logic level, not verified on hardware."
- If an acceptance criterion cannot be met (needs a backend, a device, an entitlement), do not fake it: implement what is honest, comment on the issue, status `partial`.
- If you disagree with a story or find a conflict with `MEMORY.md`/PRD, do not silently pick: write it under "Findings" in the progress file and proceed with the conservative option.

## 4. Stories, in dependency order
Already on `m1/integration` (written, compiles, **not yet unit-tested**): `Core/PrayerTimes/{TorontoCalendar,PrayerSlot,CheckInPhase,PrayerTimeline,Prayer+Display}`, `Core/Clock/OffsetClock`, `Core/History/*` (SlotOutcome, snapshots, SlotResolver, StreakCalculator, StreakSummary), and `Config/Ruki-Info.plist` (camera usage string, background modes, BG task id `com.salimsoufi.Ruki.refresh-prompts`). Tests for these are part of the stories below.

**Decisions already made — follow them (details in MEMORY.md D28–D38):**
- Check-in window setting (10/15/30) can only *shorten* the default; Maghrib stays ≤20; Fajr ignores it (adhan→sunrise). `PrayerTimeline.onTimeEnd` implements this.
- Calculation method is **read-only** ("ISNA, Toronto") — the frozen provider ignores it. Only Asr madhab is selectable. No 3-session profile (D31).
- Streak/history logic is per-slot: check-in > private mark > untracked > paused > pending/missed. Pause overlap rule protects the window the user paused in.
- Photos are kept only until the *next prayer begins* (`expiresAt`), then purged; the record stays forever, on-device only (D26). Export excludes photos.
- Do **not** add the Time-Sensitive or Sign-in-with-Apple entitlements (the Apple team's capabilities are unknown; adding them could break signing). Set `interruptionLevel = .timeSensitive` in code.
- iPhone-only, portrait-only. iOS 17 minimum.
- On the Simulator (no camera) use a placeholder camera provider that generates an image, clearly labelled, so the flow is testable. Real AVFoundation code is `#if !targetEnvironment(simulator)`. Dual-camera setup failure must fall back to sequential automatically.

| # | Order | Story | Notes |
|---|---|---|---|
| 1 | #33 | History stored on-device (SwiftData) | `CheckInRecord`, `PrayerMark`, `PauseRecord` @Model (raw-string enums), `HistoryStore` (@MainActor), `RukiModelContainer`, `SwiftDataPersistence: PersistenceProviding`, `expiresAt` photo purge, one check-in per slot. In-memory container tests. |
| 2 | #28 | Streak counted in prayers | Unit-test `StreakCalculator`/`SlotResolver` (existing). |
| 3 | #29 | Late does not break streak | Tests. |
| 4 | #30 | Pause freezes streak | Tests incl. overlap rule and open-ended pause; `HistoryStore` pause API. |
| 5 | #31 | Reset copy + lifetime + 30-day rate | `StreakSummaryPresenter`: "Streak reset. Tomorrow's Fajr is at 5:12." (use `PrayerTimeline.nextFajr`); never red/exclamation. |
| 6 | #35 | Pause never in friend payload | `FriendFacingCheckIn` Codable payload type + tests that encoded keys/Mirror contain no pause/missed field. |
| 7 | #18 | Fajr window adhan→sunrise | Already in provider; add timeline/phase tests proving Fajr is never Late before sunrise. |
| 8 | #13 | Time-Sensitive local notification at adhan | Redesign `NotificationScheduling` to `replacePending(with: [PromptSpec], soundEnabled:)`; `PromptSpec`, `PromptPlanner` (pure), `PromptScheduler`, `UserNotificationScheduler` (calendar trigger in Toronto tz, `.timeSensitive`, id prefix `ruki.prompt.`), `NotificationAuthorizing` + real/fake. Update `FakeNotificationScheduler`. |
| 9 | #16 | Never exceed 64 pending | Tests; planner caps at 64; scheduler throws above it. |
| 10 | #17 | Disable Fajr independently | `UserSettings` (@MainActor @Observable, UserDefaults-backed: madhab, checkInWindowMinutes, enabledPrayers, soundEnabled, spaceOnlyDefault, onboardingCompletedAt) + `PromptInputs`. Planner honours it. |
| 11 | #15 | 12 days forward, refresh on launch/background | `BackgroundRefresh` (BGAppRefreshTask, id above), refresh on launch/foreground/settings change/pause change. 12 days × 5 = 60 ≤ 64. |
| 12 | T1 | Supporting: app shell | `AppEnvironment`, `AppRouter`, `RootView`, `DesignSystem/` (warm palette, no red), `RukiApp` wiring, DEBUG uses `OffsetClock`. |
| 13 | #14 | Notification tap opens check-in | `NotificationCoordinator` (UNUserNotificationCenterDelegate) → router → check-in cover for that slot; foreground presentation. |
| 14 | #11 | Intention (niyyah) screen | Onboarding scaffold + copy addressing riya' (RDP-1), framed "I showed up". |
| 15 | #9 | Onboarding: madhab (+ read-only method) | No 3-session. Comment on the issue explaining D31/D33. → `partial`. |
| 16 | #10 | Notification permission + Time-Sensitive rationale | Plain-language rationale before the system prompt. |
| 17 | T2 | Supporting: Today screen | Current/next prayer, five prayer rows with state, gentle countdown (minute ticks via `clock.now()`), pause entry, user's live check-in card. |
| 18 | #12 | Add-friends step skippable / solo works | Informational last step; UI test or view-model test proving every core flow works solo. |
| 19 | #19 | Prompt→capture flow < 15 s | `CheckInViewModel` state machine: affirm ("Have you prayed X?") → camera → review → post. Camera unreachable before "I've prayed" (RDP-4). Minimal taps. |
| 20 | #23 | 80-char caption | `CheckInRules` (max 80, trim). |
| 21 | #24 | Post immediate, no draft | Discarding leaves nothing behind. |
| 22 | #25 | Late path | Copy "Checked in late — still counts."; streak unaffected. |
| 23 | #20 | Dual capture, no filters, single retake | `CameraProviding` extended (authorization, session start/stop, preview view); `AVCameraProvider` (multi-cam, with automatic fallback), `PlaceholderCameraProvider` for Simulator; retake hard-capped at 1 (button disabled, not hidden). No gallery import. |
| 24 | #22 | Space Only mode | Per-capture toggle + default from settings. |
| 25 | #21 | Sequential fallback | Feature-detected, no setting; shares the code path used when multi-cam setup fails. |
| 26 | #27 | Retake count neutral marker | Small, neutral, non-judgmental. |
| 27 | #26 | Missed-prayer private mark | Sheet on closed windows: "I prayed" / "I didn't"; on-device only; a "prayed" mark counts for the streak. |
| 28 | #34 | Pause ≤2 taps | Today → pause icon → duration (today/3/7/10 days/until I turn it back on). No reason field. Updates notifications. |
| 29 | #32 | Calendar grid | Rows=prayers, columns=days; on-time/late/missed/paused visually distinct via shape + label, **not colour alone**; no red; "your Fajr" breakdown; History tab with streak header. |
| 30 | #36 | Settings screen | Madhab, window length (10/15/30), per-prayer toggles, sound (Default/Silent), Space Only default, pause row, read-only method row, notification-status row. |
| 31 | #37 | Export + delete | Local JSON export (share sheet; no photos) and "Delete my data on this device" (wipe SwiftData, settings, notifications; return to onboarding). Comment that server-side account deletion arrives in M2 → `partial`. |
| 32 | T3 | Supporting: DEBUG tools | Settings section (DEBUG only): jump clock to "Fajr open / Dhuhr just began / Asr late phase / Maghrib late / Isha", reset, and "send a test prompt in 10 s". |
| 33 | #8 | Sign in with Apple / phone | **Deferred to M2** (needs a backend + entitlements). Do not implement. Comment on the issue; leave it open; status `deferred`. |

## 5. Completion: full verification, then merge to main
When every row in §4 is `merged`, `partial`, or `deferred` (none `todo`/`blocked`; if any is `blocked`, do NOT do this section — alert per §6 and stop):
1. Create `m1/final-verification` off `m1/integration`. Run **every** level and record the result of each in `docs/QA.md` (update the coverage table and known gaps honestly):
   - **L1 Static:** `check-no-date.sh`; grep for `fatalError`, un-commented force unwraps (`!` outside tests must have a why-comment), `print(` left in shipping code, any location/coordinate field, any analytics/third-party SDK import.
   - **L2 Build:** Debug + Release, zero warnings (CI).
   - **L3 Unit tests:** all of `RukiTests` green.
   - **L4 Time tests:** the DST/leap/year-sweep/Isha→Fajr suites plus new planner/notification tests (DST-boundary planning, 64 cap, 12-day horizon).
   - **L5 Values red-team:** perform `.claude/commands/values-check.md` against the code; write findings to `docs/QA.md`. **Any YES on items 1–6, 8, 9 blocks the merge.** Fix and re-run, or stop and alert.
   - **L6 UI + accessibility:** add an XCUITest smoke suite (launch with a DEBUG scenario; onboarding → Today → check-in → history) and `performAccessibilityAudit()`; add `RukiUITests` to CI **only if it passes reliably on CI**; otherwise leave excluded (D29) and state that plainly.
   - **L7 Independent code review:** review the full diff `main...m1/integration` for correctness, concurrency, and privacy issues; fix what you find.
   - **L8 Phone-only (cannot automate — list, do not gate):** dual-camera capture on hardware; SE-class sequential fallback; notification delivery incl. Focus/DND and the Time-Sensitive capability; background refresh; export file opens; RTL/VoiceOver on device.
2. Update `MEMORY.md` (decisions, corrections, session log: built / tested / **not tested** / uncertain) and `docs/ARCHITECTURE.md`, `README.md` status.
3. Wait for CI green on the final branch. Then `git checkout main && git pull && git merge --no-ff m1/final-verification && git push` **only if every automated level passed.** Close the M1 milestone's remaining issues appropriately. Set progress file to `M1 COMPLETE`.
4. Send the alert in §6. Then **disable yourself is not possible** — instead write `M1 COMPLETE` at the top of the progress file; on every later run, if it says `M1 COMPLETE`, do nothing except exit.

## 6. Alerts
- On completion (or a blocker that stops you): use the **PushNotification** tool (`status: "proactive"`, <200 chars, lead with what they'd act on), e.g. "Ruki M1 complete: 27 stories merged to main, 3 partial, all automated tests green. Phone-only checks listed in docs/QA.md." or "Ruki M1 blocked: <story> failing CI after 3 tries."
- **Fallback if PushNotification is unavailable or reports it did not send:** open a GitHub issue titled "M1 complete" (or "M1 blocked") that @-mentions `@ssoufii`, so GitHub mobile notifies them.
- Also state the outcome plainly in your final message.
