import Foundation
import Testing
@testable import Ruki

@Suite("DebugClockScenario")
struct DebugClockScenarioTests {
    // Toronto is UTC-4 in September (DST). Fajr 5:20/sunrise 6:52/Dhuhr 13:05/
    // Asr(standard) 16:35/checkInWindowEnd 17:05/Maghrib 19:15/checkInWindowEnd
    // 19:35/Isha 20:40, per FixedPrayerTimeProvider.
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!
    private let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard)

    private func phase(_ scenario: DebugClockScenario) -> CheckInPhase {
        let target = scenario.date(referenceNow: referenceDate)
        let slot = timeline.activeSlot(at: target)!
        // The literal default, not `UserSettings.defaultCheckInWindowMinutes`:
        // that property is `@MainActor`-isolated (it lives on `UserSettings`),
        // and this pure test helper has no reason to be.
        return timeline.phase(of: slot, at: target, userWindowMinutes: 30)
    }

    @Test("Every scenario lands inside a real, currently-open prayer window")
    func everyScenarioLandsInsideAnOpenWindow() {
        for scenario in DebugClockScenario.allCases {
            let target = scenario.date(referenceNow: referenceDate)
            #expect(timeline.activeSlot(at: target) != nil, "\(scenario.rawValue) landed outside any window")
        }
    }

    @Test("fajrOpen lands during Fajr's window, which never has a late phase (D17)")
    func fajrOpenHasNoLatePhase() {
        let target = DebugClockScenario.fajrOpen.date(referenceNow: referenceDate)
        let slot = timeline.activeSlot(at: target)
        #expect(slot?.prayer == .fajr)
        #expect(phase(.fajrOpen) == .onTime)
    }

    @Test("dhuhrJustBegan lands right at the start of Dhuhr's on-time phase")
    func dhuhrJustBeganIsOnTime() {
        let slot = timeline.activeSlot(at: DebugClockScenario.dhuhrJustBegan.date(referenceNow: referenceDate))
        #expect(slot?.prayer == .dhuhr)
        #expect(phase(.dhuhrJustBegan) == .onTime)
    }

    @Test("asrLatePhase lands in Asr's window, past the on-time cutoff")
    func asrLatePhaseIsLate() {
        let slot = timeline.activeSlot(at: DebugClockScenario.asrLatePhase.date(referenceNow: referenceDate))
        #expect(slot?.prayer == .asr)
        #expect(phase(.asrLatePhase) == .late)
    }

    @Test("maghribLatePhase lands inside Maghrib's short window, past its 20-minute cutoff")
    func maghribLatePhaseIsLate() {
        let slot = timeline.activeSlot(at: DebugClockScenario.maghribLatePhase.date(referenceNow: referenceDate))
        #expect(slot?.prayer == .maghrib)
        #expect(phase(.maghribLatePhase) == .late)
    }

    @Test("ishaJustBegan lands right at the start of Isha's on-time phase")
    func ishaJustBeganIsOnTime() {
        let slot = timeline.activeSlot(at: DebugClockScenario.ishaJustBegan.date(referenceNow: referenceDate))
        #expect(slot?.prayer == .isha)
        #expect(phase(.ishaJustBegan) == .onTime)
    }

    @Test("Every scenario has a non-empty, distinct label")
    func labelsAreDistinct() {
        let labels = DebugClockScenario.allCases.map(\.label)
        #expect(Set(labels).count == labels.count)
        #expect(labels.allSatisfy { !$0.isEmpty })
    }
}
