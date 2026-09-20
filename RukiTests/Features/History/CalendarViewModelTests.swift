import Foundation
import Testing
@testable import Ruki

@MainActor
@Suite("CalendarViewModel")
struct CalendarViewModelTests {
    // Toronto is UTC-4 in September (DST). Fajr 5:20/sunrise 6:52/Dhuhr 13:05/
    // Asr 16:35/Maghrib 19:15/Isha 20:40 local, per FixedPrayerTimeProvider.
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!

    private func freshDefaults() -> UserDefaults {
        let suiteName = "CalendarViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeViewModel(now: Date, onboardingCompletedAt: Date) throws -> (CalendarViewModel, HistoryStore, PrayerTimeline) {
        let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard)
        let userSettings = UserSettings(defaults: freshDefaults())
        userSettings.onboardingCompletedAt = onboardingCompletedAt
        let historyStore = HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        let viewModel = CalendarViewModel(
            timeline: timeline, clock: FixedClock(date: now), userSettings: userSettings, historyStore: historyStore
        )
        return (viewModel, historyStore, timeline)
    }

    @Test("A fresh account with nothing recorded shows a zero streak and no rate yet, never a crash")
    func freshAccountShowsZeroStreak() throws {
        let (viewModel, _, _) = try makeViewModel(now: referenceDate, onboardingCompletedAt: referenceDate)
        viewModel.refresh()

        #expect(viewModel.streakHeadline == "0 prayers")
        #expect(viewModel.lifetimeText == "0 prayers total")
        #expect(viewModel.thirtyDayRateText == nil)
        #expect(viewModel.loadError == nil)
    }

    @Test("Consecutive on-time check-ins produce a streak headline with the running count")
    func streakHeadlineReflectsOnTimeCheckIns() throws {
        let onboardedAt = referenceDate.addingTimeInterval(-2 * 86_400)
        let (viewModel, historyStore, timeline) = try makeViewModel(now: referenceDate, onboardingCompletedAt: onboardedAt)
        let fajr = timeline.slots(onDayOf: referenceDate).first { $0.prayer == .fajr }!
        try historyStore.recordCheckIn(
            for: fajr, isLate: false, checkedInAt: referenceDate, frontImageData: nil, rearImageData: nil,
            expiresAt: referenceDate.addingTimeInterval(3600)
        )

        viewModel.refresh()

        #expect(viewModel.streakHeadline == "1 prayers")
        #expect(viewModel.lifetimeText == "1 prayers total")
    }

    @Test("A just-reset streak shows the forward-looking reset copy, never a punitive one")
    func resetStreakShowsForwardLookingCopy() throws {
        let onboardedAt = referenceDate.addingTimeInterval(-2 * 86_400)
        let (viewModel, _, _) = try makeViewModel(now: referenceDate, onboardingCompletedAt: onboardedAt)
        // Nothing recorded: yesterday's five prayers all resolve to missed by
        // the time `referenceDate` rolls around, so the streak is reset.

        viewModel.refresh()

        #expect(viewModel.streakHeadline.contains("Streak reset"))
        #expect(viewModel.streakHeadline.contains("Fajr"))
        #expect(!viewModel.streakHeadline.lowercased().contains("fail"))
        #expect(!viewModel.streakHeadline.lowercased().contains("lost"))
    }

    @Test("The grid window is clamped to when the user started tracking, not a fixed 30 days back")
    func gridClampedToTrackingStart() throws {
        // Onboarded only one day before `referenceDate` — well inside the 30-day window.
        let onboardedAt = referenceDate.addingTimeInterval(-86_400)
        let (viewModel, _, _) = try makeViewModel(now: referenceDate, onboardingCompletedAt: onboardedAt)

        viewModel.refresh()

        let earliestDay = try #require(viewModel.grid.days.map(\.date).min())
        #expect(earliestDay >= TorontoCalendar.startOfDay(for: onboardedAt))
    }

    @Test("The breakdown lists all five prayers even with nothing recorded yet")
    func breakdownListsAllFivePrayers() throws {
        let (viewModel, _, _) = try makeViewModel(now: referenceDate, onboardingCompletedAt: referenceDate)
        viewModel.refresh()

        #expect(viewModel.breakdown.map(\.prayer) == CalendarGrid.prayerOrder)
    }
}
