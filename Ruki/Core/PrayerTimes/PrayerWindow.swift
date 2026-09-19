import Foundation

/// A single prayer's timing for one day.
///
/// - `start`: adhan — the moment the Prayer Window opens and the Prompt fires (PRD §9.1).
/// - `checkInWindowEnd`: the on-time cutoff. 30 min after `start` for most prayers,
///   20 min for Maghrib, and equal to `end` for Fajr (Option A — the window runs
///   adhan → sunrise, resolved OQ-9, PRD §9.3).
/// - `end`: the Prayer Window close. A check-in between `checkInWindowEnd` and
///   `end` is still accepted but flagged Late (PRD §7.4). Isha's `end` is the
///   next day's Fajr adhan (D30).
struct PrayerWindow: Sendable, Equatable {
    let prayer: Prayer
    let madhab: Madhab
    let start: Date
    let checkInWindowEnd: Date
    let end: Date

    /// The check-in window invariant (PRD §9.2, D16, D17).
    ///
    /// Every prayer except Fajr must leave a real Late phase: `checkInWindowEnd`
    /// strictly before `end`. Maghrib is the binding case. Fajr is the one
    /// intentional equality — Option A has no separate Late phase — so it must
    /// be exactly equal, not merely `<=`. A single `<=` for all five would let a
    /// Dhuhr window with no Late phase pass, which is the bug this guards.
    var satisfiesCheckInWindowInvariant: Bool {
        guard checkInWindowEnd > start else { return false }
        return prayer == .fajr ? checkInWindowEnd == end : checkInWindowEnd < end
    }
}
