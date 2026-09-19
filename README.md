# Ruki

**An iOS app that helps Muslims stay consistent with the five daily prayers.**

A time-sensitive notification at adhan. A short window to check in with an unfiltered photo. A circle of up to five friends who see it. That's the whole product.

Ruki borrows BeReal's check-in mechanic and points it at a real obligation. Existing prayer apps solve the *information* problem — they tell you when prayer times are. None of them solve the *accountability* problem, and a notification you can dismiss is a notification you will dismiss.

> **Status:** M0 (foundations) complete; M1 (solo loop) not started. Prayer times are a frozen placeholder until the real engine lands (before M2).
> **MVP scope:** Toronto only · iOS 17+ · Swift 6 · SwiftUI

---

## How it works

1. At adhan, a Time-Sensitive notification fires — the same moment for everyone in the city.
2. You pray.
3. You open the app, confirm you've finished, and take a dual-camera photo. No filters, no gallery import, one retake.
4. Your friends see it. You see theirs — but the feed stays blurred until you've checked in yourself.

Check-in windows are **30 minutes** from adhan, **20 for Maghrib**. After that, check-in stays open until the prayer window closes and is marked *Late*. Late still counts.

---

## What this app deliberately does not do

These aren't missing features. They're the product.

- **It never broadcasts a missed prayer.** Absence produces no network event, no gap marker, no "hasn't prayed yet" indicator. Friends see what you did, never what you didn't. This is the line between accountability and surveillance.
- **It has no leaderboard, no public feed, no discovery, no follower counts.** Your streak is visible only to you, with no way to share it. Performing worship for an audience is the failure mode this app is designed around, and the mitigation is structural rather than a disclaimer.
- **Friends' posts vanish when the next prayer begins.** No archive, nothing to scroll back through. Your own record of having prayed is kept forever, on your device.
- **It doesn't verify anything.** The photo is a self-attestation. We can't confirm anyone prayed and we don't try. Gaming it only cheats the user.
- **It stores no location.** Prayer times are computed centrally for Toronto; the server holds times, not places. There is no location column in the schema.
- **It isn't an all-purpose Islamic app.** No qibla compass, no tasbih, no Quran reader. Scope creep into "everything Islamic" is the named #1 death risk.

Full rationale in [`PRD.md` §4 — Religious Design Principles](./PRD.md).

---

## Repository map

| Path | What it is |
|---|---|
| `PRD.md` | Product spec. Canonical for **what** we build. |
| `CLAUDE.md` | Working instructions and role definitions. Canonical for **how** we work. Auto-loaded by Claude Code. |
| `MEMORY.md` | Decision log and session history. Read every session, updated every session. |
| `docs/QA.md` | Test plan and the running list of known gaps |
| `docs/ARCHITECTURE.md` | What was actually built, as opposed to what was planned |
| `Ruki/` | App source |
| `RukiTests/` | Unit tests, incl. `GoldenFiles/` and `TimeEdgeCases/` |
| `server/` | Supabase migrations, RLS policies, edge functions, cached prayer calendars |
| `scripts/` | `fetch-prayer-times.sh` and other tooling |
| `.claude/commands/` | Slash commands — see below |

```
Ruki/
├── App/                    # entry point, app-level wiring
├── Core/
│   ├── Clock/              # ClockProviding — injected everywhere
│   ├── PrayerTimes/        # PrayerTimeProviding, cache, Adhan fallback
│   ├── Notifications/      # scheduler, 64-cap manager, push+local dedup
│   ├── Persistence/        # SwiftData models
│   └── Networking/
├── Features/               # Onboarding, CheckIn, Feed, Circle, History, Settings
├── DesignSystem/
└── Resources/
```

---

## Getting started

The Xcode project is created manually (no scaffold script) via **File → New → Project… → iOS → App**, saved at the repo root as `Ruki.xcodeproj`, with SwiftUI interface, Swift language, storage set to None, and tests included.

```bash
open Ruki.xcodeproj
```

When you add Supabase later, copy `.env.example` to `.env` and fill in Supabase + APNs credentials before running.

**Requirements:** Xcode 16+, iOS 17 deployment target, a Supabase project (for M2+), an Apple Developer account with the `com.apple.developer.usernotifications.time-sensitive` entitlement (for the Time-Sensitive notification and for TestFlight/App Review — not needed for Simulator development).

### Xcode project format

Use **file-system synchronized groups** (Xcode 16+) so a `.swift` file dropped into a folder is automatically part of the target. `project.pbxproj` is machine-generated and hostile to hand-editing; if synchronized groups can't be used, switch to XcodeGen with a `project.yml`. Never edit `project.pbxproj` by hand.

---

## Architecture

| Layer | Choice |
|---|---|
| UI | SwiftUI + `@Observable`; UIKit only for camera |
| Concurrency | Swift 6 strict concurrency |
| Local storage | SwiftData — history and missed-prayer records live here **and only here** |
| Camera | AVFoundation, `AVCaptureMultiCamSession` with sequential fallback on pre-A12 |
| Prayer times | AlAdhan API fetched **server-side** and cached; Adhan-Swift bundled as offline fallback |
| Notifications | Hybrid — APNs push primary, local notifications as offline fallback, deduplicated |
| Backend | Supabase (Postgres + row-level security, which maps cleanly onto mutual-friendship authorization) |

Every external dependency sits behind a protocol so it can be faked in tests: prayer times, push, storage, camera, clock.

**`Date()` is never called in feature code.** A `ClockProviding` protocol is injected instead. Every serious bug in this product is a time bug, and untestable time logic means unfindable bugs. `/time-check` enforces this with a grep.

---

## Working with Claude Code

`CLAUDE.md` is loaded automatically. Start with `/session-start`.

| Command | Does |
|---|---|
| `/session-start` | Loads PRD + MEMORY, reports state, proposes next work |
| `/session-end` | Writes decisions, open questions, and an honest session log into MEMORY.md |
| `/time-check` | Golden-file + time edge-case suites, Maghrib invariant, no-`Date()` rule |
| `/values-check` | Red-teams the build against the Religious Design Principles. **Blocks release on FAIL.** |
| `/ship-check` | Full pre-release pass across PM, engineering, and QA |

---

## Testing

Time is the hard part. Toronto-only scope removes time-zone and high-latitude bugs from MVP, but not these:

- DST in both directions — the spring-forward jump lands near Fajr in March
- Summer solstice (Fajr ~3:30 a.m.), winter solstice, both equinoxes
- The Maghrib invariant: `checkInWindow(20m) < prayerWindow`, asserted for all 365 days, both madhabs
- Both Asr madhabs — Hanafi Asr can differ by 45+ minutes and drives a real notification
- Device clock tampering; server timestamp is authoritative for on-time status
- iOS caps pending local notifications at **64** and fails silently past it

Known gaps, documented rather than pretended-away: time-zone change mid-window, date-line crossing, high-latitude rules. All deferred until multi-city.

---

## Roadmap

| Phase | Scope | Est. |
|---|---|---|
| **M0** | Project setup, protocol boundaries, `ClockProviding`, golden-file tests | 1–2 wk |
| **M1** | Solo loop — prompts, capture, local check-in, private history. No backend. Dogfoodable. | 3 wk |
| **M2** | Supabase, auth, friends, feed, push, RLS | 3–4 wk |
| **M3** | Hardening — DST/solstice matrix, notifications, accessibility, RTL, privacy + scholar review | 2–3 wk |
| **M4** | TestFlight, 4-week soak | 4 wk |
| **M5** | App Review and launch | 1–2 wk |

Dogfoodable at ~week 5. First launch realistically 14–19 weeks.

---

## Open questions blocking M1

- **OQ-8** — Which Toronto timetable is our ground truth? Users trust their masjid's published times over a computed one, and AlAdhan's `tune` parameter exists to match them. The golden-file suite has nothing to assert against until this is settled.
- **OQ-9** — The Fajr window. Toronto Fajr is ~3:30 a.m. in June; a fixed 30-minute window would mark most genuine Fajr prayers as Late. Recommendation is to run the window adhan → sunrise, which is the actual fiqh boundary.

Full list in [`MEMORY.md`](./MEMORY.md).

---

## Before public launch

The concept and copy need review by qualified scholars across madhabs. An app that shows your worship to other people sits close to ostentation in worship, which is theologically serious, and careful design is not the same thing as a ruling. This is a launch gate, not a nice-to-have.
