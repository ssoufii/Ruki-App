import Foundation

/// A single prayer's timing for one day.
///
/// - `start`: adhan — the moment the Prayer Window opens and the Prompt fires (PRD §9.1).
/// - `checkInWindowEnd`: the on-time cutoff. 30 min after `start` for most prayers,
///   20 min for Maghrib, and equal to `end` for Fajr (Option A — the window runs
///   adhan → sunrise, resolved OQ-9, PRD §9.3).
/// - `end`: the Prayer Window close. A check-in between `checkInWindowEnd` and
///   `end` is still accepted but flagged Late (PRD §7.4).
struct PrayerWindow: Sendable, Equatable {
    let prayer: Prayer
    let madhab: Madhab
    let start: Date
    let checkInWindowEnd: Date
    let end: Date

    /// The Maghrib invariant (PRD §9.2): the check-in window must never reach
    /// or exceed the prayer window itself, for every prayer, every day.
    var satisfiesCheckInWindowInvariant: Bool {
        checkInWindowEnd <= end && checkInWindowEnd > start
    }
}
