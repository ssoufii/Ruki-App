---
description: Run the time edge-case suites, verify the Maghrib invariant and the no-Date() rule
---
Lead QA pass on time correctness.

1. `./scripts/check-no-date.sh`.
2. Run the unit tests: `xcodebuild test -project Ruki.xcodeproj -scheme Ruki -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RukiTests` (pick an available iPhone simulator if that one is missing). Report passed/failed from the `.xcresult`, not just the exit code, and any compiler warnings.
3. Confirm the suites that matter exist and ran: `RukiTests/TimeEdgeCases/` (DST both directions, leap day, year sweep, Isha→Fajr) and the invariant tests including the three that assert the invariant *rejects* bad windows.
4. `RukiTests/GoldenFiles/` does not exist until the real engine lands (Epic 13). Report it as **NOT RUN / MISSING**, never as passing.
5. Read `docs/QA.md` "Known gaps" and restate which time risks are still uncovered (solstices, winter Maghrib, DST-vs-notification scheduling, clock tampering). Any time-related change made this session that isn't covered by a test: say so.
