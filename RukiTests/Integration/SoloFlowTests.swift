import Foundation
import Testing
@testable import Ruki

/// RUKI-012: proves the app's core flows — prompt scheduling, recording a
/// check-in, the streak, and history — all work end-to-end for a fresh solo
/// account with no friend or circle state anywhere in the objects touched.
/// The first test reaches as far as recording the check-in a capture would hand
/// `HistoryStore`; the second drives the real check-in flow itself (tapped prompt
/// -> route -> affirm -> shutter -> post) against a fake camera. The camera
/// hardware is the one part no test here can exercise.
@MainActor
@Suite("Solo flow (RUKI-012)")
struct SoloFlowTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T09:40:00Z")!

    private func freshDefaults() -> UserDefaults {
        let suiteName = "SoloFlowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("Prompt scheduling, recording a check-in, and the streak all work from a fresh solo account")
    func soloAccountCompletesTheCoreLoop() throws {
        let userSettings = UserSettings(defaults: freshDefaults())
        userSettings.onboardingCompletedAt = referenceDate.addingTimeInterval(-3600)
        let trackingStart = try #require(userSettings.onboardingCompletedAt)

        let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: userSettings.madhab)
        let todaySlots = timeline.slots(onDayOf: referenceDate)

        // Prompt: scheduling needs nothing but today's slots and the user's own settings.
        let specs = PromptPlanner().plan(for: todaySlots, enabledPrayers: userSettings.enabledPrayers)
        #expect(specs.count == todaySlots.count)

        // Capture (recording the result of one): a slot and a timestamp, nothing
        // that identifies or requires any other person.
        let historyStore = HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        let fajr = try #require(todaySlots.first { $0.prayer == .fajr })
        try historyStore.recordCheckIn(
            for: fajr, isLate: false, checkedInAt: referenceDate,
            frontImageData: nil, rearImageData: nil, expiresAt: referenceDate.addingTimeInterval(3600)
        )

        // Streak: built purely from this one account's own snapshots.
        let resolver = SlotResolver(
            checkIns: try historyStore.checkInSnapshots(),
            marks: try historyStore.markSnapshots(),
            pauses: try historyStore.pauseSnapshots(),
            trackingStart: trackingStart
        )
        let resolved = todaySlots.map { (slot: $0, outcome: resolver.outcome(for: $0, now: referenceDate)) }
        let summary = StreakCalculator().summary(for: resolved, now: referenceDate)
        #expect(summary.current == 1)
        #expect(summary.lifetime == 1)

        // History: the check-in is durably queryable back out.
        #expect(try historyStore.checkInSnapshots() == [CheckInSnapshot(slotID: fajr.id, isLate: false)])
    }

    @Test("A fresh solo account goes tapped prompt -> check-in flow -> streak -> history through the real flow, with no friends")
    func soloAccountCompletesTheRealCheckInFlow() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-09-19T13:10:00-04:00")!   // Dhuhr, on time
        let userSettings = UserSettings(defaults: freshDefaults())
        userSettings.onboardingCompletedAt = now.addingTimeInterval(-3600)
        let trackingStart = try #require(userSettings.onboardingCompletedAt)
        let historyStore = HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: userSettings.madhab)
        let clock = FixedClock(date: now)
        let dhuhr = try #require(timeline.slots(onDayOf: now).first { $0.prayer == .dhuhr })

        // The tap: a notification for Dhuhr resolves to the real flow.
        let resolver = CheckInRouteResolver(
            timeline: timeline, clock: clock, userSettings: userSettings,
            historyStore: historyStore, cameraProvider: FakeCameraProvider()
        )
        guard case .flow(let flow) = resolver.route(forSlotID: dhuhr.id) else {
            Issue.record("A fresh account's open prayer must open the check-in flow"); return
        }

        // The flow: three taps, no friend anywhere.
        await flow.affirmPrayed()
        await flow.takePhoto()
        flow.post()
        #expect(flow.state == .posted)

        // Streak and history reflect it.
        let sameResolver = SlotResolver(
            checkIns: try historyStore.checkInSnapshots(), marks: try historyStore.markSnapshots(),
            pauses: try historyStore.pauseSnapshots(), trackingStart: trackingStart
        )
        let resolved = timeline.slots(onDayOf: now).map { (slot: $0, outcome: sameResolver.outcome(for: $0, now: now)) }
        let summary = StreakCalculator().summary(for: resolved, now: now)
        #expect(summary.current == 1)
        #expect(try historyStore.checkInSnapshots() == [CheckInSnapshot(slotID: dhuhr.id, isLate: false)])

        // A second tap on the same prompt does not re-open the camera.
        guard case .alreadyCheckedIn = resolver.route(forSlotID: dhuhr.id) else {
            Issue.record("A prompt tapped after checking in must not start another check-in"); return
        }
    }

    @Test("Nothing a solo account touches — settings, prompt inputs, or a check-in record — carries a friend/circle field")
    func coreTypesCarryNoFriendState() {
        let userSettings = UserSettings(defaults: freshDefaults())
        let mirrors = [
            Mirror(reflecting: userSettings.promptInputs),
            Mirror(reflecting: CheckInSnapshot(slotID: "x", isLate: false)),
        ]
        for mirror in mirrors {
            for child in mirror.children {
                let label = (child.label ?? "").lowercased()
                #expect(!label.contains("friend"))
                #expect(!label.contains("circle"))
            }
        }
    }
}
