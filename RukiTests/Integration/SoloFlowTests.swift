import Foundation
import Testing
@testable import Ruki

/// RUKI-012: proves the app's core flows — prompt scheduling, recording a
/// check-in, the streak, and history — all work end-to-end for a fresh solo
/// account with no friend or circle state anywhere in the objects touched.
/// Capture itself (the camera, RUKI-019/RUKI-020) can't be exercised outside
/// a device; this only reaches as far as recording the check-in a real
/// capture would hand `HistoryStore`.
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
