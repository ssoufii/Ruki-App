import Foundation
import Testing
@testable import Ruki

@Suite("StreakCalculator")
struct StreakCalculatorTests {
    private let calculator = StreakCalculator()
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T09:00:00Z")!

    private func slot(prayer: Prayer, hoursFromReference: Int) -> PrayerSlot {
        let start = referenceDate.addingTimeInterval(TimeInterval(hoursFromReference * 3600))
        let window = PrayerWindow(
            prayer: prayer,
            madhab: .standard,
            start: start,
            checkInWindowEnd: start.addingTimeInterval(1800),
            end: start.addingTimeInterval(3600)
        )
        return PrayerSlot(window: window)
    }

    @Test("Consecutive on-time check-ins extend the streak by one prayer each (RUKI-028)")
    func onTimeChecksInExtendStreak() {
        let resolved: [(slot: PrayerSlot, outcome: SlotOutcome)] = [
            (slot(prayer: .fajr, hoursFromReference: 0), .onTime),
            (slot(prayer: .dhuhr, hoursFromReference: 1), .onTime),
            (slot(prayer: .asr, hoursFromReference: 2), .onTime),
        ]
        let summary = calculator.summary(for: resolved, now: referenceDate.addingTimeInterval(10800))
        #expect(summary.current == 3)
        #expect(summary.lifetime == 3)
        #expect(summary.justReset == false)
    }

    @Test("A late check-in extends the streak exactly like on-time (RUKI-029)")
    func lateCheckInDoesNotBreakStreak() {
        let resolved: [(slot: PrayerSlot, outcome: SlotOutcome)] = [
            (slot(prayer: .fajr, hoursFromReference: 0), .onTime),
            (slot(prayer: .dhuhr, hoursFromReference: 1), .late),
            (slot(prayer: .asr, hoursFromReference: 2), .onTime),
        ]
        let summary = calculator.summary(for: resolved, now: referenceDate.addingTimeInterval(10800))
        #expect(summary.current == 3)
        #expect(summary.justReset == false)
    }

    @Test("A privately-marked-prayed slot counts toward the streak (PRD §7.7)")
    func markedPrayedCounts() {
        let resolved: [(slot: PrayerSlot, outcome: SlotOutcome)] = [
            (slot(prayer: .fajr, hoursFromReference: 0), .markedPrayed),
        ]
        let summary = calculator.summary(for: resolved, now: referenceDate.addingTimeInterval(3600))
        #expect(summary.current == 1)
        #expect(summary.lifetime == 1)
    }

    @Test("A miss resets the current streak to zero but leaves the lifetime total untouched (D25)")
    func missResetsCurrentButNotLifetime() {
        let resolved: [(slot: PrayerSlot, outcome: SlotOutcome)] = [
            (slot(prayer: .fajr, hoursFromReference: 0), .onTime),
            (slot(prayer: .dhuhr, hoursFromReference: 1), .onTime),
            (slot(prayer: .asr, hoursFromReference: 2), .missed),
        ]
        let summary = calculator.summary(for: resolved, now: referenceDate.addingTimeInterval(10800))
        #expect(summary.current == 0)
        #expect(summary.lifetime == 2)
        #expect(summary.justReset == true)
    }

    @Test("A paused slot is skipped entirely: it neither extends nor resets the streak (RUKI-030, RDP-3)")
    func pausedSlotFreezesStreak() {
        let resolved: [(slot: PrayerSlot, outcome: SlotOutcome)] = [
            (slot(prayer: .fajr, hoursFromReference: 0), .onTime),
            (slot(prayer: .dhuhr, hoursFromReference: 1), .paused),
            (slot(prayer: .asr, hoursFromReference: 2), .onTime),
        ]
        let summary = calculator.summary(for: resolved, now: referenceDate.addingTimeInterval(10800))
        #expect(summary.current == 2)
        #expect(summary.lifetime == 2)
        #expect(summary.justReset == false)
    }

    @Test("A pending (still-open) slot is skipped and is never mistaken for a reset")
    func pendingSlotDoesNotCountAsReset() {
        let resolved: [(slot: PrayerSlot, outcome: SlotOutcome)] = [
            (slot(prayer: .fajr, hoursFromReference: 0), .onTime),
            (slot(prayer: .dhuhr, hoursFromReference: 1), .pending),
        ]
        let summary = calculator.summary(for: resolved, now: referenceDate.addingTimeInterval(3600))
        #expect(summary.current == 1)
        #expect(summary.justReset == false)
    }

    @Test("The 30-day on-time rate is on-time over settled prayers within the window")
    func thirtyDayRate() {
        let resolved: [(slot: PrayerSlot, outcome: SlotOutcome)] = [
            (slot(prayer: .fajr, hoursFromReference: 0), .onTime),
            (slot(prayer: .dhuhr, hoursFromReference: 1), .late),
            (slot(prayer: .asr, hoursFromReference: 2), .missed),
        ]
        let summary = calculator.summary(for: resolved, now: referenceDate.addingTimeInterval(10800))
        #expect(summary.thirtyDayOnTimeRate == 1.0 / 3.0)
    }

    @Test("The 30-day rate excludes settled prayers older than 30 days")
    func thirtyDayRateExcludesOldPrayers() {
        let old = slot(prayer: .fajr, hoursFromReference: -31 * 24)
        let recent = slot(prayer: .dhuhr, hoursFromReference: 0)
        let resolved: [(slot: PrayerSlot, outcome: SlotOutcome)] = [
            (old, .missed),
            (recent, .onTime),
        ]
        let summary = calculator.summary(for: resolved, now: referenceDate.addingTimeInterval(3600))
        #expect(summary.thirtyDayOnTimeRate == 1.0)
    }

    @Test("The 30-day rate is nil until something has settled")
    func thirtyDayRateNilWithNothingSettled() {
        let resolved: [(slot: PrayerSlot, outcome: SlotOutcome)] = [
            (slot(prayer: .fajr, hoursFromReference: 0), .pending),
        ]
        let summary = calculator.summary(for: resolved, now: referenceDate)
        #expect(summary.thirtyDayOnTimeRate == nil)
    }
}
