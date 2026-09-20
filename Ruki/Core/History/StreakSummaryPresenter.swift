import Foundation

/// Turns a `StreakSummary` into the copy shown on the profile (RUKI-031).
/// Tone rules (CLAUDE.md) apply most directly here: forward-looking on a
/// reset, no red, no "FAILED" — the reset headline never mentions the miss.
struct StreakSummaryPresenter: Sendable {
    /// The headline shown at the top of the streak card. Forward-looking when
    /// the streak just reset ("Streak reset. Tomorrow's Fajr is at 5:12."),
    /// otherwise just the running count.
    nonisolated func headline(for summary: StreakSummary, nextFajr: PrayerSlot?) -> String {
        guard summary.justReset else {
            return String(localized: "\(summary.current) prayers")
        }
        guard let nextFajr else {
            return String(localized: "Streak reset.")
        }
        return String(localized: "Streak reset. Tomorrow's Fajr is at \(Self.timeText(for: nextFajr.window.start)).")
    }

    /// Never resets (D25) — one of the three numbers a reset leaves untouched.
    nonisolated func lifetimeText(for summary: StreakSummary) -> String {
        String(localized: "\(summary.lifetime) prayers total")
    }

    /// `nil` until something has settled, so the profile doesn't show "0%" on day one.
    nonisolated func thirtyDayRateText(for summary: StreakSummary) -> String? {
        guard let rate = summary.thirtyDayOnTimeRate else { return nil }
        let percent = Int((rate * 100).rounded())
        return String(localized: "\(percent)% on time, last 30 days")
    }

    // A fresh `DateFormatter` per call, not a shared static one: `DateFormatter`
    // isn't `Sendable`, and this type must stay usable from any context.
    private static func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TorontoCalendar.timeZone
        return formatter.string(from: date)
    }
}
