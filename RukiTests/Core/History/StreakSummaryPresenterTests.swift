import Foundation
import Testing
@testable import Ruki

@Suite("StreakSummaryPresenter")
struct StreakSummaryPresenterTests {
    private let presenter = StreakSummaryPresenter()

    private func fajrSlot(at date: Date) -> PrayerSlot {
        let window = PrayerWindow(
            prayer: .fajr,
            madhab: .standard,
            start: date,
            checkInWindowEnd: date.addingTimeInterval(3600),
            end: date.addingTimeInterval(3600)
        )
        return PrayerSlot(window: window)
    }

    @Test("An ongoing streak's headline is just the count, never mentioning a reset")
    func ongoingStreakHeadline() {
        let summary = StreakSummary(current: 7, lifetime: 40, thirtyDayOnTimeRate: 0.9, justReset: false)
        let headline = presenter.headline(for: summary, nextFajr: nil)
        #expect(headline.contains("reset") == false)
        #expect(headline.contains("7"))
    }

    @Test("A reset headline is forward-looking and names tomorrow's Fajr time (RUKI-031), never the miss")
    func resetHeadlineIsForwardLooking() {
        let summary = StreakSummary(current: 0, lifetime: 40, thirtyDayOnTimeRate: 0.9, justReset: true)
        // 5:12 a.m. Toronto time (EDT, UTC-4) on the reference date.
        let fajrTime = ISO8601DateFormatter().date(from: "2026-09-19T09:12:00Z")!
        let headline = presenter.headline(for: summary, nextFajr: fajrSlot(at: fajrTime))
        #expect(headline.contains("Streak reset."))
        #expect(headline.contains("5:12"))
        #expect(headline.localizedCaseInsensitiveContains("missed") == false)
        #expect(headline.localizedCaseInsensitiveContains("failed") == false)
    }

    @Test("A reset headline with no known next Fajr degrades gracefully")
    func resetHeadlineWithoutNextFajr() {
        let summary = StreakSummary(current: 0, lifetime: 40, thirtyDayOnTimeRate: 0.9, justReset: true)
        let headline = presenter.headline(for: summary, nextFajr: nil)
        #expect(headline.contains("Streak reset."))
    }

    @Test("Lifetime text never resets to zero alongside a current-streak reset")
    func lifetimeTextSurvivesReset() {
        let summary = StreakSummary(current: 0, lifetime: 128, thirtyDayOnTimeRate: nil, justReset: true)
        #expect(presenter.lifetimeText(for: summary).contains("128"))
    }

    @Test("30-day rate text is nil when the summary has no rate yet")
    func thirtyDayRateTextNilWhenUnavailable() {
        let summary = StreakSummary.empty
        #expect(presenter.thirtyDayRateText(for: summary) == nil)
    }

    @Test("30-day rate text renders as a whole-number percentage")
    func thirtyDayRateTextRendersPercentage() {
        let summary = StreakSummary(current: 3, lifetime: 3, thirtyDayOnTimeRate: 0.5, justReset: false)
        #expect(presenter.thirtyDayRateText(for: summary) == "50% on time, last 30 days")
    }
}
