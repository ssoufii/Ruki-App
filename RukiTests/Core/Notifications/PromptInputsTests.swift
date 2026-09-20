import Foundation
import Testing
@testable import Ruki

@MainActor
@Suite("PromptInputs")
struct PromptInputsTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T09:00:00Z")!

    private func slot(prayer: Prayer) -> PrayerSlot {
        let window = PrayerWindow(
            prayer: prayer,
            madhab: .standard,
            start: referenceDate,
            checkInWindowEnd: referenceDate.addingTimeInterval(1800),
            end: referenceDate.addingTimeInterval(3600)
        )
        return PrayerSlot(window: window)
    }

    private func freshDefaults() -> UserDefaults {
        let suiteName = "PromptInputsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("Disabling Fajr in UserSettings excludes it from what actually gets scheduled, end to end (RUKI-017)")
    func disablingFajrInSettingsExcludesItFromScheduling() async throws {
        let settings = UserSettings(defaults: freshDefaults())
        settings.enabledPrayers.remove(.fajr)
        let inputs = settings.promptInputs

        let fake = FakeNotificationScheduler()
        let promptScheduler = PromptScheduler(scheduler: fake)
        let slots = [slot(prayer: .fajr), slot(prayer: .dhuhr), slot(prayer: .asr)]

        try await promptScheduler.refresh(slots: slots, inputs: inputs)

        let scheduled = await fake.scheduled
        #expect(scheduled.map(\.prayer).sorted { $0.rawValue < $1.rawValue } == [.asr, .dhuhr])
    }

    @Test("A fresh UserSettings schedules all five prayers")
    func freshSettingsScheduleAllFive() async throws {
        let settings = UserSettings(defaults: freshDefaults())
        let inputs = settings.promptInputs

        let fake = FakeNotificationScheduler()
        let promptScheduler = PromptScheduler(scheduler: fake)
        let slots = Prayer.allCases.map(slot(prayer:))

        try await promptScheduler.refresh(slots: slots, inputs: inputs)

        let scheduled = await fake.scheduled
        #expect(Set(scheduled.map(\.prayer)) == Set(Prayer.allCases))
    }

    @Test("soundEnabled flows from settings through to the scheduler call")
    func soundEnabledFlowsThrough() async throws {
        let settings = UserSettings(defaults: freshDefaults())
        settings.soundEnabled = false
        let inputs = settings.promptInputs

        let fake = FakeNotificationScheduler()
        let promptScheduler = PromptScheduler(scheduler: fake)

        try await promptScheduler.refresh(slots: [slot(prayer: .dhuhr)], inputs: inputs)

        #expect(await fake.lastSoundEnabled == false)
    }
}
