import Foundation
import Testing
@testable import Ruki

@Suite("FixedPrayerTimeProvider")
struct FixedPrayerTimeProviderTests {
    private let provider = FixedPrayerTimeProvider()
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!

    @Test(
        "Check-in window invariant: strictly inside the prayer window, except Fajr (PRD §9.2, D16, D17)",
        arguments: [Madhab.standard, Madhab.hanafi]
    )
    func maghribInvariantHolds(madhab: Madhab) {
        let windows = provider.prayerWindows(for: referenceDate, madhab: madhab)
        for window in windows {
            #expect(
                window.satisfiesCheckInWindowInvariant,
                "\(window.prayer) violates checkInWindow < prayerWindow for \(madhab)"
            )
        }
    }

    @Test("Fajr's check-in window equals its prayer window (Option A, OQ-9)")
    func fajrWindowRunsAdhanToSunrise() {
        let windows = provider.prayerWindows(for: referenceDate, madhab: .standard)
        let fajr = windows.first { $0.prayer == .fajr }!
        #expect(fajr.checkInWindowEnd == fajr.end)
    }

    @Test("Maghrib's check-in window is 20 minutes, not 30 (PRD §9.2)")
    func maghribCheckInWindowIsTwentyMinutes() {
        let windows = provider.prayerWindows(for: referenceDate, madhab: .standard)
        let maghrib = windows.first { $0.prayer == .maghrib }!
        let duration = maghrib.checkInWindowEnd.timeIntervalSince(maghrib.start)
        #expect(duration == 20 * 60)
    }

    @Test("Hanafi Asr is later than Standard Asr")
    func hanafiAsrIsLaterThanStandard() {
        let standard = provider.prayerWindows(for: referenceDate, madhab: .standard)
            .first { $0.prayer == .asr }!
        let hanafi = provider.prayerWindows(for: referenceDate, madhab: .hanafi)
            .first { $0.prayer == .asr }!
        #expect(hanafi.start > standard.start)
    }

    @Test("The five prayer windows are ordered and non-overlapping across the day")
    func windowsAreOrderedAcrossTheDay() {
        let windows = provider.prayerWindows(for: referenceDate, madhab: .standard)
        #expect(windows.map(\.prayer) == [.fajr, .dhuhr, .asr, .maghrib, .isha])
        for (earlier, later) in zip(windows, windows.dropFirst()) {
            #expect(earlier.start < later.start)
            #expect(earlier.end <= later.start)
        }
    }

    @Test("The same wall-clock times are returned regardless of the date requested")
    func returnsIdenticalTimesForAnyDate() {
        let today = provider.prayerWindows(for: referenceDate, madhab: .standard)
        let aMonthLater = referenceDate.addingTimeInterval(30 * 24 * 60 * 60)
        let later = provider.prayerWindows(for: aMonthLater, madhab: .standard)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!

        for (t, l) in zip(today, later) {
            let tComponents = calendar.dateComponents([.hour, .minute], from: t.start)
            let lComponents = calendar.dateComponents([.hour, .minute], from: l.start)
            #expect(tComponents == lComponents, "\(t.prayer) drifted — the fixed provider must return the same wall-clock time every day")
        }
    }
}
