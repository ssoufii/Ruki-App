# Context — Product Requirements Document

**Working title:** Context
**Platform:** iOS (Swift / SwiftUI), iPhone-first
**Doc owner:** Lead PM (Claude)
**Status:** v0.1 — Draft for review
**Last updated:** 2026-08-18

---

## 1. Summary

Context is a small, private social app that helps Muslims stay consistent with the five daily prayers (*salah*) by combining a real-time check-in prompt with a close circle of friends who can see it.

The core loop borrows BeReal's spontaneity mechanic: a notification arrives at an unpredictable moment, you have a short window to capture an unfiltered photo, and your friends see it. The difference is that the moment isn't random — it's tied to an actual prayer window, and the photo is proof to yourself and your friends that you prayed.

The product is not a competition, a leaderboard, or a piety scoreboard. It is a nudge and a small circle of accountability.

---

## 2. Problem

Consistency in salah is the most commonly cited struggle among practicing Muslims — not belief, not knowledge, but *showing up five times a day, on time, every day*. The failure modes are well understood:

- **Time-blindness.** The window opens and closes and you didn't notice. Especially Fajr and Asr.
- **Delay compounding.** "I'll pray in ten minutes" repeated until the window closes.
- **Isolation.** Praying alone at home or at a desk has no social scaffolding. Praying in congregation does.
- **No feedback loop.** Nothing records whether the week went well or badly, so nothing improves.

Existing prayer apps (Muslim Pro, Athan, Pillars) solve the *information* problem — they tell you when prayer times are. None of them solve the *accountability* problem. A notification you can dismiss is a notification you will dismiss.

**Hypothesis:** A small number of people who will see whether you checked in creates enough gentle social pressure to close the gap between intention and action — without turning worship into performance.

---

## 3. Goals & Non-Goals

### Goals (v1)
- G1. Deliver a reliable, time-sensitive prompt inside each prayer window that breaks through Focus modes.
- G2. Make check-in take under 15 seconds from notification tap to posted.
- G3. Make a user's consistency visible to a small, mutually-approved circle of friends.
- G4. Give the user private, honest data about their own consistency over time.
- G5. Do all of the above without creating a mechanism for showing off, shaming, or surveilling.

### Non-Goals (v1)
- ❌ Qibla compass, tasbih counter, Quran reader, dhikr, hadith of the day. Feature creep into "everything Islamic app" is the #1 way this product dies. Prayer times exist only as engine input, not as a browsable feature.
- ❌ Public profiles, discovery, follower counts, explore feed, virality mechanics.
- ❌ Android, web, iPad, Watch (v2+; Watch is a strong v2 candidate).
- ❌ **Any city other than Toronto.** MVP is Toronto-only (§8.1). Users outside the GTA are shown a waitlist screen rather than wrong prayer times. Multi-city is the first post-MVP priority.
- ❌ Mosque finder, community/masjid groups, halaqa scheduling.
- ❌ Any form of monetization. Charging money to help someone pray is a brand problem and possibly a fiqh problem. Revisit only after product-market fit, and only for cosmetic or storage features.
- ❌ Verification that the user *actually* prayed. Impossible and undesirable. The photo is a self-attestation, not evidence.

---

## 4. Religious Design Principles

These are hard constraints, not preferences. Every feature is checked against them. Violating one is a P0 bug regardless of engagement impact.

### RDP-1 — Guard against *riya'* (ostentation in worship)
Performing worship for the sake of being seen is theologically serious. This app sits uncomfortably close to that line by design, so the mitigation must be structural, not a disclaimer:

- No public feed, no discovery, no strangers. Friends must be mutually approved.
- No global leaderboards, no ranking of friends by consistency, ever.
- Streaks are **private to the user by default**. Sharing a streak is opt-in and reciprocal.
- No like counts, no reaction counts displayed as a number.
- Copy throughout is framed as *"I showed up"*, never *"look how devoted I am."*
- Onboarding includes an explicit screen about intention (*niyyah*) and the risk of riya'. Users who don't want the social layer can run the app fully solo.

**Action:** Before public launch, the concept and copy are reviewed by at least two qualified scholars across madhabs. This is a launch gate, not a nice-to-have. See Open Question OQ-1.

### RDP-2 — Missed prayers are never broadcast
A missed prayer is a private matter between a person and God. The app **only ever transmits positive check-ins.** Absence produces no event, no notification to friends, no gap marker, no "hasn't prayed yet today" indicator. Friends see what you did, never what you didn't.

This is the single most important rule in the product. It is also the main thing that separates accountability from surveillance.

### RDP-3 — Silent, dignified pause
Users must be able to pause the app entirely with one tap, with no explanation required, no friend-visible signal, and no streak penalty.

This exists primarily because women do not pray during menstruation and post-natal bleeding. An app that nags a woman five times a day during her period, or that makes her absence conspicuous to her friends, is a broken app and a humiliating one. It also serves illness, travel, grief, and reversion/learning periods.

Requirements: reachable in ≤2 taps, no reason field, durations of "today / 3 days / 7 days / 10 days / until I turn it back on", zero network-visible artifact, streak frozen (not broken) on resume.

### RDP-4 — Never photograph someone praying
Salah requires focus (*khushu'*); interrupting it to take a photo defeats the purpose and is disrespectful. The capture screen is only reachable *after* the user marks the prayer complete, and the copy is explicit: photograph the moment after, not the prayer itself. Suggested subjects surfaced in-app: your prayer space, your mat, the view, your hands, a post-prayer selfie.

If capture-mid-prayer becomes a common pattern in testing, we add friction or restrict to non-selfie capture.

### RDP-5 — Modesty and privacy by default
Photos taken at home may include family members, unveiled women, or private interiors. Mitigations: friends-only visibility always, no screenshots without notifying the poster, 24-hour expiry by default, no download/save of others' photos, no photo forwarding, and a "space only" capture mode that uses the rear camera only.

### RDP-6 — Accommodate difference, don't arbitrate it
The app supports multiple calculation methods, both Asr madhabs, Hanafi/Shafi'i differences, Shia combining of Dhuhr–Asr and Maghrib–Isha (3 sessions rather than 5), Jumu'ah replacing Dhuhr on Friday, and traveler's concessions (*qasr* / *jam'*). The app never tells a user their practice is wrong. Defaults are set once at onboarding and are trivially changeable.

---

## 5. Users

**Primary: "The Inconsistent Practicing Muslim," 18–32.**
Prays, believes it matters, hits maybe 3 of 5 on an average day. Fajr is the recurring failure. Has a prayer app installed and has notification-blindness to it. Has 3–15 friends who are in exactly the same position. Motivated by not letting friends down more than by self-discipline.

**Secondary: "The Rebuilder."**
Returning to practice after a gap, or a recent revert. Needs structure and a non-judgmental environment. Extremely sensitive to anything that feels like being graded. This user churns instantly if the app feels punitive.

**Secondary: "The Anchor."**
Consistent already. Joins because a friend asked. Provides the social gravity that makes the friend graph work. Gets value from the private history and from supporting others. Must not be turned into a performance object for the group.

**Explicit anti-user:** anyone who wants a public audience for their worship. The product should be actively unattractive to them.

---

## 6. Core Concepts

| Concept | Definition |
|---|---|
| **Prayer Window** | The canonical time range in which a given prayer is valid, computed locally from date, coordinates, calculation method, and madhab. |
| **Prompt** | A time-sensitive push fired at a randomized offset inside a Prayer Window. |
| **Check-in Window** | A fixed duration (default 15 min) after the Prompt during which a check-in counts as *On Time*. |
| **Check-in** | A user-created record that a prayer was completed. Contains a photo, a prayer identifier, a timestamp, and an on-time/late flag. |
| **Late Check-in** | A check-in made after the Check-in Window closes but before the Prayer Window closes. Visible, marked as late, counts for the streak. |
| **Missed** | No check-in before the Prayer Window closed. Stored **locally only**. Never transmitted. Never rendered to anyone but the user. |
| **Circle** | A user's mutually-approved friends. Cap of 25 in v1 (see OQ-4). |
| **Pause** | RDP-3 state. All prompts suppressed, streak frozen, nothing visible externally. |
| **Streak** | Consecutive days with all obligatory prayers checked in. Private by default. |

---

## 7. Features

Priority: **P0** = required for v1 launch · **P1** = fast-follow · **P2** = later

### 7.1 Onboarding — P0
1. Sign in with Apple (primary) or phone number.
2. Location permission (When In Use). Explain plainly: used to compute prayer times on-device; coarse coordinates only; never shared with friends. Manual city entry must be a first-class alternative for users who decline.
3. Calculation method + Asr madhab + practice profile (5-session / 3-session).
4. Notification permission, with the Time-Sensitive rationale explained.
5. Intention screen (RDP-1).
6. Add friends (skippable — solo mode is fully supported).

**Rule:** the user reaches a functional state before being asked to add a single friend. The app must be useful alone.

### 7.2 Prayer Time Engine — P0
See §8. Fully on-device, offline-capable.

### 7.3 The Prompt — P0
- One prompt per obligatory prayer per day (5, or 3 for combining users).
- **Fires at adhan — the exact start of the prayer window.** Not randomized. See §9.
- Delivered as a **Time-Sensitive** notification so it pierces Focus and Do Not Disturb. Requires the `com.apple.developer.usernotifications.time-sensitive` entitlement.
- Check-in Window: **30 minutes** from adhan. **20 minutes for Maghrib.** Fajr is an exception — see §9.3.
- Tapping opens directly to the check-in screen for that prayer. No home screen, no interstitial.

### 7.4 Check-in & Capture — P0
- Flow: prompt → tap → "Have you prayed *Asr*?" → **I've prayed** → camera.
- Default capture: dual (front + rear simultaneous, `AVCaptureMultiCamSession`) on supported hardware; sequential fallback otherwise.
- Alternative: **Space Only** mode (rear camera only) for users who don't want to be in frame. Selectable per-capture and settable as a default.
- No filters. No gallery import. No editing beyond a single retake.
- Retakes are counted and displayed as a small, non-judgmental marker, as in BeReal.
- Optional caption, 80 characters.
- Post is immediate; no draft state.
- **Late path:** if the Check-in Window has closed, the flow is identical but the resulting check-in carries a `late` flag. Copy stays warm: "Checked in late — still counts."
- **Missed path:** if the Prayer Window closed with no check-in, the user can privately mark it prayed or missed for their own records. This never leaves the device.

### 7.5 Circle / Friends — P0
- Add by username or invite link. Mutual approval required both directions.
- No suggestions, no contact-list scraping, no "people you may know."
- Removing a friend is silent and immediate; historical check-ins become invisible to them at once.
- Block, with no notification to the blocked user.
- **Cap: 5 friends (MVP.)** Deliberately tight. This resolves OQ-4 in the direction of intimacy: at five people you are accountable to a circle, not an audience, which is the strongest available structural defence against riya' (RDP-1). It also means the feed is small enough to read in one sitting, and it makes the invite flow high-signal — you have to choose who matters.
  - Enforced server-side, configurable without a client release, so we can raise it if testing shows five is too sparse.
  - Copy should frame the cap as intentional, not as a limitation to be upgraded past. Never present it as a paywall or a "Pro" gate.
  - Watch in M4: with a 5-cap, a user whose friends are inactive has a dead feed. Track how many users have ≥2 *active* friends.

### 7.6 Feed — P0
- Reverse-chronological, friends only, last 24 hours only.
- Each card: photo(s), friend name, prayer name, relative time, on-time/late marker, retake count.
- **You cannot see today's feed until you have checked in for the current prayer window.** Directly lifted from BeReal and it is the mechanic that makes the loop work. Blurred until you post.
- Reactions: a small fixed set of supportive responses (e.g. *masha'Allah*, *jazakAllah khayr*, a heart). Counts are shown to the poster only, never aggregated publicly.
- No comments in v1 (see OQ-5).

### 7.7 Personal History — P0
- Calendar grid, one row per prayer, one column per day.
- Rolling 30-day on-time rate, per-prayer breakdown (the "your Fajr is the problem" insight).
- Fully private. No export to friends. No screenshot-to-share affordance in v1.
- Tone rule: the history view describes, it never scolds. No red, no "FAILED," no guilt copy.

### 7.8 Pause — P0
RDP-3. Settings and long-press on the app's main action. Two taps maximum.

### 7.9 Settings — P0
Calculation method, madhab, high-latitude rule, manual location override, check-in window duration (10/15/30 min), per-prayer prompt toggle, notification sound, Space Only default, pause, data export, delete account.

### 7.10 Fast-follow — P1
- Jumu'ah handling (Friday Dhuhr as its own prayer type, with mosque-attendance flag).
- Traveler mode (qasr/jam' — suppresses prompts appropriately, shortens expectations).
- Sunnah / nafl / witr optional logging, private only.
- Apple Watch check-in.
- Widgets: next prayer, time remaining.
- Localization: Arabic, Urdu, Turkish, Bahasa, French — **with full RTL layout support.**

### 7.11 Later — P2
- Small named groups within a Circle (family, halaqa).
- Ramadan mode (suhoor/iftar timing, taraweeh).
- Live Activities for the check-in countdown.
- Notification snooze ("prompt me again in 10 min," capped at one per window).

---

## 8. Prayer Time Engine

### 8.1 MVP scope: Toronto only
v1 serves a single city — **Toronto, ON** (43.6532° N, 79.3832° W, `America/Toronto`). This is a good scoping decision and it eliminates a large share of the hardest QA surface:

- One time zone. No mid-window time-zone changes, no date-line crossing.
- 43.65° N is comfortably below the ~48° latitude where twilight-angle math degenerates, so **high-latitude rules are not needed for MVP.** They become required the moment we expand to the UK or Scandinavia.
- Prayer times are identical for every user, which means we can fetch them **once, centrally,** rather than per-user.

DST still applies (Toronto observes it), so DST testing stays in scope.

### 8.2 Source of prayer times
**Recommendation: AlAdhan API, fetched server-side and cached, not called from the device.**

AlAdhan is a free REST API returning prayer times by coordinates, city, or address, with the calculation-method, `school` (0 = Shafi / 1 = Hanafi), and `tune` parameters we need. The `tune` parameter lets us offset individual prayers by minutes to match a specific Toronto masjid's published timetable, which matters more than it sounds — see §8.4.

**Architecture:** a scheduled job fetches Toronto's full annual calendar from AlAdhan once and stores it. Clients fetch our precomputed schedule, not AlAdhan's. This means:
- Zero third-party network calls from user devices (privacy — §11).
- No dependency on AlAdhan's uptime at prayer time.
- One request per year instead of one per user per day.
- We can correct or `tune` times centrally without a client release.

Endpoint shape (verify against current docs before implementing):
```
GET https://api.aladhan.com/v1/calendar
    ?latitude=43.6532&longitude=-79.3832
    &method={ISNA|MWL}&school=0&year=2026&month=…
```

**Client-side fallback:** bundle Adhan-Swift and compute locally if the cached schedule is stale or missing. Prayer times must never fail to resolve because a network call failed — the entire product is a notification that has to fire.

Everything sits behind a `PrayerTimeProviding` protocol so the API, the cache, the local library, and a test fake are interchangeable.

### 8.3 Configuration (MVP)
- **Calculation method:** ISNA and Muslim World League offered; ISNA default for Toronto. Confirm against what local masjids actually publish — see OQ-8.
- **Asr madhab:** Standard (Shafi'i/Maliki/Hanbali, shadow ×1) or Hanafi (shadow ×2). Both required at MVP; Toronto's Muslim population is substantially Hanafi and the Asr difference is often 45+ minutes. Getting this wrong sends a large fraction of users a notification at the wrong time.
- **High-latitude rules:** out of scope for MVP (§8.1). Required before any expansion north of ~48°.
- **Location:** not requested at MVP. Toronto is assumed. This removes the location permission prompt from onboarding entirely, which is a meaningful conversion win and a privacy win. Location permission returns when we add cities.

### 8.4 The masjid-timetable problem
Computed times and the times a user's local masjid publishes often differ by a few minutes — masjids apply their own precaution offsets. Users will trust their masjid over our app and will report our times as "wrong."

Mitigation: pick one widely-used Toronto reference timetable as our ground truth for MVP, use AlAdhan's `tune` parameter to match it, and state in-app which reference we follow. Do not silently diverge. Resolving OQ-8 is a prerequisite to M1.

### 8.5 Caching
Ship with the current year embedded in the app bundle. Refresh the rolling schedule on launch and via `BGAppRefreshTask`. Keep at least 30 days available locally at all times so a user with no connectivity for a month still gets prompted.

---

## 9. Prompt Timing

### 9.1 The prompt fires at adhan
No randomization. `promptAt = prayerStart` for every prayer.

**This is a deliberate departure from BeReal and it changes the product's character. Naming it explicitly so we stop designing around a property we no longer have:**

- ✅ **It aligns with the practice.** Praying at the beginning of the window (*awwal al-waqt*) is preferred. A random prompt 40 minutes in implicitly nudges users to delay; a prompt at adhan nudges them to pray at the best time. This is the right call.
- ✅ **It makes the app legible.** Users know what the notification means the instant it arrives. Random timing would have required explaining the mechanic.
- ✅ **Everyone in Toronto is prompted simultaneously**, so the feed fills in a burst. That synchrony is genuinely valuable — it recreates a small piece of what praying in congregation feels like, and it's what makes BeReal's feed feel alive.
- ⚠️ **We lose the anti-staging property.** A user can pre-shoot a photo, because they know exactly when the prompt lands. Acceptable: the PRD already states we do not and cannot verify that anyone actually prayed (§3, Non-Goals). The photo is a self-attestation. Gaming it only cheats the user. But we should not describe the app as "proof" in any copy.
- ⚠️ **We become a second adhan notification.** Most users already have one from an existing prayer app. The differentiator has to be the check-in and the friends, not the reminder. Copy must not read like a generic prayer alert.

### 9.2 Check-in Windows
| Prayer | Window | Rationale |
|---|---|---|
| Fajr | adhan → sunrise (see §9.3) | Fixed 30 min is unworkable — see below |
| Dhuhr | 30 min | |
| Asr | 30 min | |
| Maghrib | **20 min** | Maghrib's own window is short; a 30-min check-in window would consume most of it |
| Isha | 30 min | |

After the Check-in Window closes, check-in remains available until the *prayer window* closes and is flagged **Late**. Late still counts for the streak. (§7.4)

**Invariant to assert in code and test:** `checkInWindow < (prayerEnd - prayerStart)` for every prayer, every day of the year, in Toronto. Maghrib is the binding case. If this is ever violated, clamp the check-in window to the prayer window and log it.

### 9.3 Fajr — the 30-minute window does not work here
This needs a decision before M1.

Toronto's Fajr moves dramatically across the year. Near the summer solstice, Fajr is roughly **3:30–4:00 a.m.** with sunrise around 5:35 a.m. A rigid 30-minute window means an on-time check-in requires being awake and finished praying by about 4:10 a.m. In midwinter, Fajr is closer to 6:00 a.m. with a similarly short runway to sunrise.

Most users who pray Fajr do it somewhere between adhan and sunrise, not in the first half hour. **If we ship a 30-minute Fajr window, the majority of genuine Fajr prayers get marked Late — which will read as the app calling them a failure for a prayer they actually made.** That's the exact guilt-spiral risk in R5.

Three options:

| Option | Description | Trade-off |
|---|---|---|
| **A (recommended)** | Fajr's Check-in Window runs **adhan → sunrise**. On time means "before sunrise," which is the actual fiqh boundary. | Window is 1–2h, much softer than other prayers. Inconsistent, but correctly inconsistent. |
| B | Fixed 30 min, but the *prompt* fires at a user-set wake time rather than adhan. | Preserves symmetry; requires per-user config in onboarding. |
| C | Fixed 30 min from adhan, same as other prayers. | Simple. Will mark most real Fajr prayers as Late. Not recommended. |

Option A also lets us keep a single notification. Flagged as **OQ-9**.

Independent of the above: the Fajr prompt is Time-Sensitive with a distinct sound and does not respect Sleep Focus, and users can disable it entirely without disabling the other four. Some people have a working Fajr routine and don't want a 4 a.m. notification. Never force it.

**Optional Fajr Alarm (P1):** an alarm-style notification at a user-set time before adhan, so the app can be the wake-up rather than competing with one.

### 9.4 Scheduling implementation
Unchanged in structure from the randomized design — hybrid push + local:

- **Server push (primary).** APNs, cron-driven from the precomputed Toronto schedule. Fixable without a client release.
- **Local notifications (fallback).** Scheduled 12 days forward, refreshed on launch and via `BGAppRefreshTask`. Guarantees the app works offline.

Fixed adhan timing makes this *easier* than the randomized design: prompt times are now identical for all Toronto users, so the push job is a single batch send per prayer rather than a per-user schedule.

**Hard iOS constraint, unchanged:** at most **64 pending local notifications**. At 5/day that's 12.8 days. Exceeding the cap fails silently — explicit unit test required.

**Dedup:** if the push arrives, cancel the matching local notification and vice versa. Never double-notify. With a fixed prompt time, a duplicate is far more visible than it would have been with randomized timing, so this needs to be right.

### 9.4 Scheduling implementation
Hybrid, because both approaches alone are broken:

- **Server push (primary).** APNs, scheduled server-side. Prevents gaming via device clock manipulation, allows us to fix timing bugs without a client release, and is the source of truth for randomization.
- **Local notifications (fallback).** `UNUserNotificationCenter`, scheduled 12 days forward, refreshed on launch and via `BGAppRefreshTask`. Guarantees the app works with no network.

**Hard iOS constraint:** an app may have at most **64 pending local notifications**. At 5/day that's 12.8 days. The scheduler must respect this cap and prioritize the nearest dates. Exceeding it fails silently — this is a known trap and needs an explicit unit test.

**Dedup:** if the push arrives, cancel the matching local notification, and vice versa. Never double-notify.

---

## 10. Technical Architecture

### 10.1 Client
| Layer | Choice | Rationale |
|---|---|---|
| Min OS | iOS 17.0 | `@Observable`, SwiftData, modern SwiftUI. ~95% device coverage by launch. |
| Language | Swift 6, strict concurrency | Data-race safety at compile time; this app has real concurrency around camera + notifications + sync. |
| UI | SwiftUI, UIKit escape hatch for camera | Camera work is materially easier in `UIViewControllerRepresentable`. |
| State | Observation framework (`@Observable`) | |
| Local persistence | SwiftData | Check-in history, prayer cache, settings. Missed prayers live here and only here. |
| Camera | AVFoundation, `AVCaptureMultiCamSession` | Multi-cam requires A12 Bionic or newer; feature-detect and fall back. |
| Networking | URLSession + async/await, thin client | No Alamofire. |
| Architecture | MVVM + feature modules, protocol-boundaried | Every external dependency (prayer times, push, storage, clock) behind a protocol so it can be faked in tests. **`Date()` is never called directly in feature code** — a `ClockProviding` protocol is injected. This is what makes the time logic testable. |

### 10.2 Backend
**Recommendation for v1: Supabase.** Postgres with row-level security, auth, storage with signed URLs, and edge functions — RLS maps cleanly onto "only my mutual friends can read my check-ins," which is the entire authorization model. Cheaper and less lock-in than Firebase, faster than building it.

**Considered and rejected for v1:**
- *Firebase* — faster still, but the security-rules model is weaker for a mutual-friendship graph and vendor lock-in is worse.
- *Vapor (all-Swift)* — appealing for a Swift-first team and worth revisiting at scale, but shipping auth, storage, and push infrastructure ourselves would add ~6 weeks to v1.

**Services:**
- Auth: Sign in with Apple + phone OTP.
- Storage: photos in object storage, short-lived signed URLs, hard delete at 24h+grace via scheduled job.
- Push: APNs via edge function, cron-driven from precomputed prompt schedule.
- No analytics SDK that phones home religious-practice data. Self-hosted, aggregate-only, opt-in. See §11.

### 10.3 Data model (abbreviated)
```
User        id, appleUserID?, phoneHash?, username, displayName, avatarURL?,
            createdAt, calcMethod, madhab, highLatRule, practiceProfile,
            pausedUntil?   // pausedUntil is NEVER included in any friend-facing payload

Friendship  userA, userB, status(pending|accepted|blocked), createdAt
            // canonical ordering on (userA, userB) to prevent duplicate rows

CheckIn     id, userID, prayer(fajr|dhuhr|asr|maghrib|isha|jumuah),
            prayedAt, promptedAt, isLate, retakeCount, caption?,
            frontPhotoKey?, rearPhotoKey, expiresAt

Reaction    id, checkInID, userID, kind

// Local-only, never synced:
MissedRecord   date, prayer, note?
PauseRecord    startedAt, endsAt?
```

**Note there is no `location` column anywhere.** Deliberate — see §11.

---

## 11. Privacy, Security & Safety

This section is a launch gate.

### 11.1 This is special-category data
Religious belief and practice is a **special category of personal data** under GDPR Article 9 and equivalents elsewhere. The entire dataset — every row — is a record of someone's religious observance. Requirements:

- Explicit, granular, unbundled consent at onboarding. Not buried in a ToS checkbox.
- Documented lawful basis, DPIA completed before launch.
- Full export and hard delete, self-serve, no email-support loop.
- Data minimization enforced by schema, not policy.

### 11.2 Threat model includes state actors
Muslims are surveilled, detained, and persecuted on the basis of religious practice in multiple jurisdictions. A database that maps identity → location → religious observance → time, with a social graph attached, is a genuinely dangerous artifact. Design accordingly:

- **Never store coordinates server-side.** Prayer times are computed on-device. The server receives a *prompt schedule* (times only), not a location. This is why there is no location column.
- Photos encrypted at rest, short-lived signed URLs, hard delete at expiry.
- No third-party analytics, ad SDKs, or attribution SDKs. None.
- Minimal retention: check-ins expire from the server at 24h. Long-term history lives on-device.
- Evaluate E2E encryption of photo payloads for v2 — the server does not need to be able to read them. Note the cost: it complicates moderation and multi-device.
- Publish a transparency policy stating what we hold and what we would be able to hand over. The honest answer should be "very little."

### 11.3 Safety & moderation
- Report/block on every card. Report reasons kept short and specific.
- Server-side hash check against known CSAM databases on upload — non-negotiable, and required by our storage providers regardless.
- Because content is friends-only and expires in 24h, our moderation surface is small. Reports of abuse between mutual friends are handled by account action, not content review.
- Screenshot detection → notify the photo's owner.
- Minimum age 13; if we cannot get the age-gating right, raise to 16. Given the audience skews young this needs real attention, not a birthdate field.

---

## 12. Success Metrics

**The north star is deliberately not engagement.** Optimizing for time-in-app is the wrong objective for an app about worship, and would push us straight into the failure modes in §4. If a design change increases session length, that is a neutral-to-negative signal.

### Primary
- **Weekly on-time check-in rate** = on-time check-ins ÷ prompts delivered, per active user.
- **Week-4 retention** of the prayer behavior, not the app.
- **Self-reported improvement** — a single in-app question at day 30: "Are you praying more consistently than a month ago?"

### Secondary
- Median time from prompt tap to posted check-in (target < 15s).
- Notification delivery success rate (target > 98%).
- Fajr on-time rate specifically — the hardest prayer and the clearest proof of value.
- Circle size distribution (healthy is 3–10; if median is 20+, we've built the wrong thing).

### Guardrail / anti-metrics — investigate if these rise
- Sessions per day above ~6.
- Time in feed per session above ~90s.
- Pause-feature usage dropping to near zero (suggests it's undiscoverable or feels penalized).
- Any correlation between friend count and check-in rate that looks like performance pressure.

---

## 13. QA Strategy

Full plan lives in `/docs/QA.md`. Summary of what makes this app unusually hard to test:

**Time is the hard part.** Every meaningful bug in this product is a time bug. Toronto-only scope removes a lot of this surface — but not the parts that bite.

**In scope for MVP:**
- **DST transitions, both directions** (Toronto observes DST). Specifically: does a notification scheduled across the spring-forward boundary fire at the right wall-clock time? The 2 a.m. → 3 a.m. jump lands near Fajr in March — test it directly.
- **Summer and winter solstice, both equinoxes.** Fajr at ~3:30 a.m. and the very short Maghrib windows are the stress cases.
- **Maghrib window invariant** (§9.2) asserted for all 365 days of the year, both madhabs. Automated, not manual.
- **Both Asr madhabs**, since Hanafi Asr can differ by 45+ minutes and drives a real notification.
- Device clock tampering — server timestamp is authoritative for on-time status.
- Midnight boundary, leap year, year rollover, Dec 31 → Jan 1 schedule refresh.
- AlAdhan API unavailable → does the local Adhan-Swift fallback produce times within tolerance of the cached ones?

**Deferred until multi-city (document as known gaps, don't pretend they're covered):**
- Time-zone change mid-window, date-line crossing, high-latitude rules.

**Golden-file testing:** snapshot Toronto prayer times for every day of a full year × 2 madhabs × supported methods, against the chosen reference timetable (§8.4, OQ-8). Any engine change that moves these fails CI. This is cheap to build and it is the highest-value test suite in the project.

**Notification reliability matrix:** app foreground / background / force-quit / device restarted; Low Power Mode; Focus, Sleep Focus, DND; notification permission revoked mid-use; airplane mode; the 64-pending-local-notification ceiling; push and local both firing (dedup).

**Device matrix:** oldest supported (multi-cam unsupported → fallback path), current, Pro. Camera permission denied. Storage full.

**Accessibility:** VoiceOver on every flow, Dynamic Type to AX5 without truncation, reduced motion, colorblind-safe on-time/late distinction (never color alone), **full RTL layout** — a large share of the target audience reads Arabic or Urdu and RTL bugs are the most common failure in apps aimed at this market.

**Red-team the values, not just the code.** Before each release, a review pass asks: can this build shame a user? Can it broadcast an absence? Can a user infer a friend's missed prayer or paused state from anything visible? Does anything in it reward performance over practice? A "yes" is a release blocker.

---

## 14. Milestones

| Phase | Scope | Est. |
|---|---|---|
| **M0 — Foundations** | Xcode project, SPM deps, CI, protocol boundaries, `ClockProviding`, Adhan integration, golden-file tests. No UI. | 1–2 wk |
| **M1 — Solo loop** | Prompt scheduling (local only), capture, local check-in, private history. Fully usable alone, no backend. Dogfoodable. | 3 wk |
| **M2 — Backend & social** | Supabase, auth, friends, feed, push, RLS. | 3–4 wk |
| **M3 — Hardening** | Time-zone/DST/latitude matrix, notification matrix, accessibility, RTL scaffolding, privacy review, scholar review. | 2–3 wk |
| **M4 — TestFlight** | 30–50 users across ≥4 time zones incl. one high-latitude. 4-week soak. Watch Fajr rate and pause usage. | 4 wk |
| **M5 — Launch** | App Review, App Store, launch. | 1–2 wk |

Realistic first-launch estimate: **14–19 weeks.** M1 is dogfoodable at week ~5, which is the important date.

---

## 15. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R1 | The app encourages riya' — worship becomes performance | **Critical** | §4 structural mitigations; scholar review as launch gate; private-by-default streaks; kill the feature rather than compromise |
| R2 | Prayer times wrong, or diverging from users' masjid timetables | **Critical** | Single Toronto reference timetable (§8.4), `tune` offsets, full-year golden-file tests, in-app "these times look wrong" report |
| R2b | Fajr window marks genuine prayers as Late, users feel judged | High | Resolve OQ-9 toward Option A; measure Fajr on-time rate in M4 before launch |
| R2c | We read as just another adhan notification and get dismissed like one | High | Copy and notification design must foreground the check-in and the circle, not the time |
| R3 | Notification doesn't fire → core loop is dead | High | Hybrid push + local, Time-Sensitive entitlement, delivery telemetry, 64-notification cap test |
| R4 | Data breach exposes religious practice + social graph | **Critical** | §11: no server-side location, 24h expiry, no third-party SDKs, E2E for v2 |
| R5 | Guilt spiral — user misses prayers, feels judged, deletes app | High | RDP-2 (never broadcast absence), warm copy, pause feature, no punitive UI |
| R6 | Sect/madhab differences alienate a segment | Medium | Configurable everything, no defaults presented as correct |
| R7 | Solo users churn because nobody they know is on it | High | App must be genuinely valuable with zero friends; invite flow is easy but never gated |
| R8 | App Review rejection (Time-Sensitive entitlement, religious content) | Medium | Justify entitlement clearly in review notes; the use case is legitimate and well-precedented |

---

## 16. Open Questions

| # | Question | Owner | Blocking |
|---|---|---|---|
| OQ-1 | Which scholars review the concept, and across which madhabs? Needed before public launch. | Founder | M3 |
| OQ-2 | Is "Context" the final name? It's abstract and doesn't signal the product. Candidates worth testing: *Salah*, *Rakah*, *Five*, *On Time*, *Wudu*. | Founder | M4 |
| OQ-3 | Should Shia 3-session support ship in v1 or v1.1? Affects engine scope. | PM | M1 |
| ~~OQ-4~~ | ~~Circle cap size?~~ **Resolved: 5 for MVP.** Server-configurable. | — | Closed |
| **OQ-8** | Which Toronto timetable is our ground truth, and what `tune` offsets match it? ISNA vs MWL, and which masjid do we align to? **Blocks M1** — we cannot ship notifications we can't defend as correct. | Founder | M1 |
| **OQ-9** | Fajr window: Option A (adhan → sunrise), B (user-set prompt time), or C (fixed 30 min)? Recommending A. **Blocks M1.** | PM | M1 |
| OQ-10 | Toronto-only gating — how do we detect and handle out-of-area signups? IP-based with manual override, or self-declared? Affects onboarding. | Eng | M2 |
| OQ-5 | Comments: valuable encouragement, or the vector by which judgment enters the product? Leaning toward permanently excluded. | PM | M2 |
| OQ-6 | Should missed prayers sync across a user's own devices? Convenient, but it means they leave the device. | Eng | M2 |
| OQ-7 | Does the "blur feed until you check in" mechanic create pressure to check in without having prayed (i.e. to lie)? Needs explicit testing in M4. | PM/QA | M4 |

---

## Appendix A — The Five Prayers

| Prayer | Window opens | Window closes | Notes |
|---|---|---|---|
| Fajr | Dawn (astronomical twilight) | Sunrise | Hardest to keep. Special handling §9.3 |
| Dhuhr | Sun past zenith | Asr begins | Replaced by Jumu'ah on Friday |
| Asr | Shadow = 1× (or 2×, Hanafi) object length | Sunset | Second-most missed |
| Maghrib | Sunset | Isha begins | Shortest window — timing guard critical |
| Isha | Twilight ends | Midnight (or Fajr) | High-latitude rules apply |

### Toronto-specific notes (43.65° N)
- **Fajr** swings from roughly 3:30 a.m. (June) to roughly 6:00 a.m. (December). This is the widest swing of any prayer and the reason §9.3 exists.
- **Maghrib** window is at its shortest in winter. Assert the §9.2 invariant against the 20-minute check-in window across the full year.
- **Asr** differs by 45+ minutes between Standard and Hanafi. Both must be supported at MVP.
- **Isha** is late in summer (past 10 p.m.) — a 30-minute window ending near 11 p.m. is fine, but watch for users asleep before it.
- Latitude is well below the ~48° threshold where twilight-angle calculations break down, so no high-latitude rule is needed.
