import Foundation
import Observation

/// The private profile numbers: streak, lifetime total, 30-day rate. Visible
/// only to the person (D24) — nothing here is ever sent anywhere.
@MainActor
@Observable
final class ProfileViewModel {
    private(set) var summary = StreakSummary.empty
    /// Only set right after a reset — the warm, forward-looking line (CLAUDE.md Tone).
    private(set) var resetNote: String?
    private(set) var memberSince: Date?
    private(set) var loadError: (any Error)?

    private let timeline: PrayerTimeline
    private let clock: any ClockProviding
    private let userSettings: UserSettings
    private let historyStore: HistoryStore
    private let streakCalculator = StreakCalculator()
    private let presenter = StreakSummaryPresenter()

    init(timeline: PrayerTimeline, clock: any ClockProviding, userSettings: UserSettings, historyStore: HistoryStore) {
        self.timeline = timeline
        self.clock = clock
        self.userSettings = userSettings
        self.historyStore = historyStore
    }

    /// Whole-percent 30-day on-time rate, or `nil` until something has settled (no "0%" on day one).
    var onTimePercent: Int? {
        summary.thirtyDayOnTimeRate.map { Int(($0 * 100).rounded()) }
    }

    func refresh() {
        let now = clock.now()
        let trackingStart = historyStore.trackingStart ?? userSettings.onboardingCompletedAt ?? now
        do {
            let resolver = SlotResolver(
                checkIns: try historyStore.checkInSnapshots(),
                marks: try historyStore.markSnapshots(),
                pauses: try historyStore.pauseSnapshots(),
                trackingStart: trackingStart
            )
            let resolved = timeline.slots(from: trackingStart, through: now)
                .map { (slot: $0, outcome: resolver.outcome(for: $0, now: now)) }
            summary = streakCalculator.summary(for: resolved, now: now)
            resetNote = summary.justReset ? presenter.headline(for: summary, nextFajr: timeline.nextFajr(after: now)) : nil
            memberSince = trackingStart
            loadError = nil
        } catch {
            loadError = error
        }
    }
}
