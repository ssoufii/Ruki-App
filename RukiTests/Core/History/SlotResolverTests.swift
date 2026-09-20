import Foundation
import Testing
@testable import Ruki

@Suite("SlotResolver")
struct SlotResolverTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T09:00:00Z")!

    private func slot(prayer: Prayer = .dhuhr, hoursFromReference: Int, durationMinutes: Int = 60) -> PrayerSlot {
        let start = referenceDate.addingTimeInterval(TimeInterval(hoursFromReference * 3600))
        let window = PrayerWindow(
            prayer: prayer,
            madhab: .standard,
            start: start,
            checkInWindowEnd: start.addingTimeInterval(1800),
            end: start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        )
        return PrayerSlot(window: window)
    }

    @Test("A check-in resolves to onTime or late depending on CheckInSnapshot.isLate")
    func checkInResolvesOnTimeOrLate() {
        let onTimeSlot = slot(hoursFromReference: 0)
        let lateSlot = slot(prayer: .asr, hoursFromReference: 1)
        let resolver = SlotResolver(
            checkIns: [
                CheckInSnapshot(slotID: onTimeSlot.id, isLate: false),
                CheckInSnapshot(slotID: lateSlot.id, isLate: true),
            ],
            marks: [],
            pauses: [],
            trackingStart: referenceDate.addingTimeInterval(-3600)
        )
        let now = referenceDate.addingTimeInterval(7200)
        #expect(resolver.outcome(for: onTimeSlot, now: now) == .onTime)
        #expect(resolver.outcome(for: lateSlot, now: now) == .late)
    }

    @Test("A private mark resolves to markedPrayed or missed, and a check-in takes precedence over a mark")
    func markResolvesAndCheckInTakesPrecedence() {
        let markedPrayedSlot = slot(hoursFromReference: 0)
        let markedMissedSlot = slot(prayer: .asr, hoursFromReference: 1)
        let bothSlot = slot(prayer: .isha, hoursFromReference: 2)
        let resolver = SlotResolver(
            checkIns: [CheckInSnapshot(slotID: bothSlot.id, isLate: false)],
            marks: [
                MarkSnapshot(slotID: markedPrayedSlot.id, kind: .prayed),
                MarkSnapshot(slotID: markedMissedSlot.id, kind: .missed),
                MarkSnapshot(slotID: bothSlot.id, kind: .missed),
            ],
            pauses: [],
            trackingStart: referenceDate.addingTimeInterval(-3600)
        )
        let now = referenceDate.addingTimeInterval(10800)
        #expect(resolver.outcome(for: markedPrayedSlot, now: now) == .markedPrayed)
        #expect(resolver.outcome(for: markedMissedSlot, now: now) == .missed)
        #expect(resolver.outcome(for: bothSlot, now: now) == .onTime)
    }

    @Test("A slot before tracking started is notTracked, even once its window has closed")
    func slotBeforeTrackingStartIsNotTracked() {
        let earlySlot = slot(hoursFromReference: -10)
        let resolver = SlotResolver(checkIns: [], marks: [], pauses: [], trackingStart: referenceDate)
        #expect(resolver.outcome(for: earlySlot, now: referenceDate.addingTimeInterval(3600)) == .notTracked)
    }

    @Test("An open window with no record is pending; a closed one with no record is missed")
    func pendingUntilWindowCloses() {
        let s = slot(hoursFromReference: 0, durationMinutes: 60)
        let resolver = SlotResolver(checkIns: [], marks: [], pauses: [], trackingStart: referenceDate.addingTimeInterval(-3600))
        #expect(resolver.outcome(for: s, now: referenceDate.addingTimeInterval(1800)) == .pending)
        #expect(resolver.outcome(for: s, now: referenceDate.addingTimeInterval(3660)) == .missed)
    }

    @Test("A pause overlapping the window resolves it to paused, even once the window has closed")
    func pauseOverlapResolvesToPaused() {
        let s = slot(hoursFromReference: 0, durationMinutes: 60)
        let pause = PauseSnapshot(startedAt: referenceDate.addingTimeInterval(1800), endsAt: referenceDate.addingTimeInterval(5400))
        let resolver = SlotResolver(checkIns: [], marks: [], pauses: [pause], trackingStart: referenceDate.addingTimeInterval(-3600))
        #expect(resolver.outcome(for: s, now: referenceDate.addingTimeInterval(7200)) == .paused)
    }

    @Test("An open-ended pause (endsAt == nil, 'until I turn it back on') still overlaps and protects the streak")
    func openEndedPauseOverlaps() {
        let s = slot(hoursFromReference: 0, durationMinutes: 60)
        let pause = PauseSnapshot(startedAt: referenceDate.addingTimeInterval(-3600), endsAt: nil)
        let resolver = SlotResolver(checkIns: [], marks: [], pauses: [pause], trackingStart: referenceDate.addingTimeInterval(-7200))
        #expect(resolver.outcome(for: s, now: referenceDate.addingTimeInterval(7200)) == .paused)
    }

    @Test("Pausing mid-window still protects the window the user was already in the middle of (D38)")
    func pauseStartingMidWindowStillProtects() {
        let s = slot(hoursFromReference: 0, durationMinutes: 60)
        // The pause begins after the window's start but before it ends.
        let pause = PauseSnapshot(startedAt: referenceDate.addingTimeInterval(1800), endsAt: referenceDate.addingTimeInterval(9000))
        let resolver = SlotResolver(checkIns: [], marks: [], pauses: [pause], trackingStart: referenceDate.addingTimeInterval(-3600))
        #expect(resolver.outcome(for: s, now: referenceDate.addingTimeInterval(7200)) == .paused)
    }

    @Test("A pause that ends before the window starts does not protect it")
    func pauseEndingBeforeWindowDoesNotOverlap() {
        let s = slot(hoursFromReference: 2, durationMinutes: 60)
        let pause = PauseSnapshot(startedAt: referenceDate, endsAt: referenceDate.addingTimeInterval(3600))
        let resolver = SlotResolver(checkIns: [], marks: [], pauses: [pause], trackingStart: referenceDate.addingTimeInterval(-3600))
        #expect(resolver.outcome(for: s, now: referenceDate.addingTimeInterval(10800)) == .missed)
    }
}
