import Foundation
import Observation

/// Backs `CalendarView` (RUKI-032): the streak header (RUKI-031's presenter,
/// wired into a real screen for the first time), the grid, and the
/// per-prayer breakdown. Everything is computed from `clock.now()`, never
/// `Date()` (CLAUDE.md's no-`Date()` rule).
@MainActor
@Observable
final class CalendarViewModel {
    /// The grid shows at most this many trailing days, clamped to when the
    /// user actually started tracking — matches the "last 30 days" window
    /// the streak card's on-time rate already uses, so the two numbers on
    /// this screen describe the same span.
    static let gridWindowDays = 30

    private let timeline: PrayerTimeline
    private let clock: any ClockProviding
    private let userSettings: UserSettings
    private let historyStore: HistoryStore

    private let streakCalculator = StreakCalculator()
    private let streakPresenter = StreakSummaryPresenter()
    private let gridBuilder = CalendarGridBuilder()

    private(set) var grid = CalendarGrid(days: [])
    private(set) var breakdown: [PrayerBreakdown] = []
    private(set) var streakHeadline = ""
    private(set) var lifetimeText = ""
    private(set) var thirtyDayRateText: String?
    /// Surfaced rather than swallowed — a fetch failure leaves the screen at
    /// its last-known state instead of silently going blank.
    private(set) var loadError: (any Error)?

    init(timeline: PrayerTimeline, clock: any ClockProviding, userSettings: UserSettings, historyStore: HistoryStore) {
        self.timeline = timeline
        self.clock = clock
        self.userSettings = userSettings
        self.historyStore = historyStore
    }

    func refresh() {
        let now = clock.now()
        let trackingStart = userSettings.onboardingCompletedAt ?? now

        do {
            let resolver = SlotResolver(
                checkIns: try historyStore.checkInSnapshots(),
                marks: try historyStore.markSnapshots(),
                pauses: try historyStore.pauseSnapshots(),
                trackingStart: trackingStart
            )

            // The streak/lifetime/rate numbers cover the user's whole tracked
            // history, not just the visible grid window — a streak longer
            // than 30 days must still read as itself.
            let resolved = timeline.slots(from: trackingStart, through: now)
                .map { (slot: $0, outcome: resolver.outcome(for: $0, now: now)) }
            let summary = streakCalculator.summary(for: resolved, now: now)
            streakHeadline = streakPresenter.headline(for: summary, nextFajr: timeline.nextFajr(after: now))
            lifetimeText = streakPresenter.lifetimeText(for: summary)
            thirtyDayRateText = streakPresenter.thirtyDayRateText(for: summary)

            let earliestGridDay = TorontoCalendar.startOfDay(byAdding: -(Self.gridWindowDays - 1), to: now)
            let gridStart = max(trackingStart, earliestGridDay)
            grid = gridBuilder.grid(from: gridStart, through: now, timeline: timeline, resolver: resolver, now: now)
            breakdown = gridBuilder.breakdown(for: grid)
            loadError = nil
        } catch {
            loadError = error
        }
    }
}
