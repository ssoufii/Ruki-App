import Foundation
import Testing
@testable import Ruki

/// Time edge cases the fixed provider can honestly cover today: every day of a
/// year, both DST transitions, and a leap day. What it cannot cover — seasonal
/// drift, solstices, and the Maghrib window at its winter minimum — needs the
/// real engine and is tracked as a known gap in docs/QA.md.
@Suite("Time edge cases — FixedPrayerTimeProvider")
struct FixedProviderTimeEdgeCaseTests {
    private let provider = FixedPrayerTimeProvider()

    private static let toronto: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // Force unwrap is safe: "America/Toronto" is a valid, stable IANA identifier.
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    /// Noon Toronto time — far from any 2 a.m. DST transition.
    private static func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        // Force unwrap is safe: the arguments in this file are all real dates.
        return toronto.date(from: components)!
    }

    private static func wallClock(_ date: Date) -> DateComponents {
        toronto.dateComponents([.hour, .minute], from: date)
    }

    @Test(
        "Check-in window invariant holds on every day of a full year (PRD §13)",
        arguments: [Madhab.standard, Madhab.hanafi]
    )
    func invariantHoldsEveryDayOfTheYear(madhab: Madhab) {
        let start = Self.noon(2026, 9, 19)
        // 366 covers a full cycle including both DST transitions; the leap day
        // is covered separately below because 2027 is not a leap year.
        for offset in 0..<366 {
            let date = Self.toronto.date(byAdding: .day, value: offset, to: start)!
            for window in provider.prayerWindows(for: date, madhab: madhab) {
                #expect(
                    window.satisfiesCheckInWindowInvariant,
                    "\(window.prayer) violates the invariant on day +\(offset) (\(madhab))"
                )
            }
        }
    }

    @Test("Wall-clock prayer times are unchanged across both 2026–27 DST transitions")
    func wallClockTimesSurviveDST() {
        let baseline = provider.prayerWindows(for: Self.noon(2026, 9, 19), madhab: .standard)
            .map { Self.wallClock($0.start) }

        // Fall back Nov 1 2026, spring forward Mar 14 2027, and the day after each.
        for (y, m, d) in [(2026, 11, 1), (2026, 11, 2), (2027, 3, 14), (2027, 3, 15)] {
            let windows = provider.prayerWindows(for: Self.noon(y, m, d), madhab: .standard)
            #expect(windows.map { Self.wallClock($0.start) } == baseline, "drifted on \(y)-\(m)-\(d)")
        }
    }

    @Test("The leap day is a normal day")
    func leapDayWorks() {
        let windows = provider.prayerWindows(for: Self.noon(2028, 2, 29), madhab: .standard)
        #expect(windows.count == 5)
        #expect(windows.allSatisfy { $0.satisfiesCheckInWindowInvariant })
        let isha = windows.last!
        // Isha on Feb 29 must end at Fajr on Mar 1, not a nonexistent Feb 30.
        let end = Self.toronto.dateComponents([.month, .day], from: isha.end)
        #expect(end.month == 3 && end.day == 1)
    }

    @Test("Isha ends at the next day's Fajr adhan, including across year rollover (D30)")
    func ishaEndsAtNextFajr() {
        for (y, m, d) in [(2026, 9, 19), (2026, 12, 31), (2026, 11, 1)] {
            let today = Self.noon(y, m, d)
            let tomorrow = Self.toronto.date(byAdding: .day, value: 1, to: today)!
            let isha = provider.prayerWindows(for: today, madhab: .standard).last!
            let nextFajr = provider.prayerWindows(for: tomorrow, madhab: .standard).first!
            #expect(isha.prayer == .isha && nextFajr.prayer == .fajr)
            #expect(isha.end == nextFajr.start, "Isha and next Fajr must meet exactly on \(y)-\(m)-\(d)")
        }
    }

    // MARK: - The invariant itself

    /// The invariant is only worth having if it can fail. These pin down the
    /// cases the old `<=`-for-everything check let through.
    @Test("Invariant rejects a non-Fajr window with no Late phase")
    func invariantRejectsZeroLatePhase() {
        let start = Self.noon(2026, 9, 19)
        let end = start.addingTimeInterval(30 * 60)
        let window = PrayerWindow(prayer: .dhuhr, madhab: .standard,
                                  start: start, checkInWindowEnd: end, end: end)
        #expect(!window.satisfiesCheckInWindowInvariant)
    }

    @Test("Invariant rejects a check-in window that outlives its prayer window")
    func invariantRejectsOverrun() {
        let start = Self.noon(2026, 9, 19)
        let window = PrayerWindow(prayer: .maghrib, madhab: .standard, start: start,
                                  checkInWindowEnd: start.addingTimeInterval(20 * 60),
                                  end: start.addingTimeInterval(15 * 60))
        #expect(!window.satisfiesCheckInWindowInvariant)
    }

    @Test("Invariant requires Fajr's check-in window to equal its prayer window (Option A)")
    func invariantRequiresFajrEquality() {
        let start = Self.noon(2026, 9, 19)
        let end = start.addingTimeInterval(90 * 60)
        let equal = PrayerWindow(prayer: .fajr, madhab: .standard,
                                 start: start, checkInWindowEnd: end, end: end)
        let clamped = PrayerWindow(prayer: .fajr, madhab: .standard, start: start,
                                   checkInWindowEnd: start.addingTimeInterval(30 * 60), end: end)
        #expect(equal.satisfiesCheckInWindowInvariant)
        #expect(!clamped.satisfiesCheckInWindowInvariant)
    }
}
