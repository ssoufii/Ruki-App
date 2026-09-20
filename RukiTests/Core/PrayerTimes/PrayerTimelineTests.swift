import Foundation
import Testing
@testable import Ruki

@Suite("PrayerTimeline")
struct PrayerTimelineTests {
    private let provider = FixedPrayerTimeProvider()
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!

    private func timeline(madhab: Madhab = .standard) -> PrayerTimeline {
        PrayerTimeline(provider: provider, madhab: madhab)
    }

    private func fajrSlot(from timeline: PrayerTimeline) -> PrayerSlot {
        timeline.slots(onDayOf: referenceDate).first { $0.prayer == .fajr }!
    }

    @Test(
        "Fajr's on-time cutoff is always sunrise (window.end), regardless of the check-in window setting (D17, D33)",
        arguments: [10, 15, 30]
    )
    func fajrOnTimeEndIgnoresUserWindowSetting(userWindowMinutes: Int) {
        let timeline = timeline()
        let fajr = fajrSlot(from: timeline)
        #expect(timeline.onTimeEnd(of: fajr.window, userWindowMinutes: userWindowMinutes) == fajr.window.end)
    }

    @Test("Fajr is never Late: it's onTime up to sunrise, then closed, with no phase in between (D17)")
    func fajrIsNeverLate() {
        let timeline = timeline()
        let fajr = fajrSlot(from: timeline)

        // Sampled every 5 minutes across the whole window plus a margin either side.
        var t = fajr.window.start.addingTimeInterval(-300)
        while t <= fajr.window.end.addingTimeInterval(300) {
            let phase = timeline.phase(of: fajr, at: t, userWindowMinutes: 30)
            #expect(phase != .late, "Fajr must never report .late (got .late at \(t))")
            t = t.addingTimeInterval(300)
        }
    }

    @Test("Fajr is exactly onTime immediately before sunrise and closed immediately after")
    func fajrPhaseBoundary() {
        let timeline = timeline()
        let fajr = fajrSlot(from: timeline)
        #expect(timeline.phase(of: fajr, at: fajr.window.end.addingTimeInterval(-1), userWindowMinutes: 30) == .onTime)
        #expect(timeline.phase(of: fajr, at: fajr.window.end, userWindowMinutes: 30) == .closed)
    }

    @Test("Fajr before its adhan is upcoming, never onTime or late")
    func fajrBeforeAdhanIsUpcoming() {
        let timeline = timeline()
        let fajr = fajrSlot(from: timeline)
        #expect(timeline.phase(of: fajr, at: fajr.window.start.addingTimeInterval(-1), userWindowMinutes: 30) == .upcoming)
    }

    @Test("A non-Fajr prayer's on-time cutoff does honour the user's shorter window setting (D33)")
    func nonFajrPrayerHonoursUserWindowSetting() {
        let timeline = timeline()
        let dhuhr = timeline.slots(onDayOf: referenceDate).first { $0.prayer == .dhuhr }!
        let cutoff = timeline.onTimeEnd(of: dhuhr.window, userWindowMinutes: 10)
        #expect(cutoff == dhuhr.window.start.addingTimeInterval(10 * 60))
        #expect(cutoff < dhuhr.window.checkInWindowEnd)
    }

    @Test("A non-Fajr prayer does reach a Late phase before its window closes")
    func nonFajrPrayerHasLatePhase() {
        let timeline = timeline()
        let dhuhr = timeline.slots(onDayOf: referenceDate).first { $0.prayer == .dhuhr }!
        let midLate = dhuhr.window.checkInWindowEnd.addingTimeInterval(60)
        #expect(midLate < dhuhr.window.end)
        #expect(timeline.phase(of: dhuhr, at: midLate, userWindowMinutes: 30) == .late)
    }
}
