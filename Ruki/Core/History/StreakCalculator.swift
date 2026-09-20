import Foundation

/// Computes the private streak (D25). Pure.
///
/// Rules, all from PRD §7.7:
/// - on-time, late, and privately-marked-prayed all extend the streak;
/// - a miss resets it to zero;
/// - paused and pending slots are skipped — a pause *freezes* the chain, it
///   never breaks it (RDP-3), and an open window hasn't been decided yet.
struct StreakCalculator: Sendable {
    static let rateWindowDays = 30

    nonisolated func summary(for resolved: [(slot: PrayerSlot, outcome: SlotOutcome)], now: Date) -> StreakSummary {
        var run = 0
        var lifetime = 0
        var lastSettled: SlotOutcome?
        var onTimeRecent = 0
        var settledRecent = 0

        let rateStart = now.addingTimeInterval(-TimeInterval(Self.rateWindowDays * 24 * 60 * 60))

        for (slot, outcome) in resolved {
            guard outcome.isResolved else { continue }
            lastSettled = outcome
            if outcome.counts {
                run += 1
                lifetime += 1
            } else {
                run = 0
            }
            if slot.window.start >= rateStart {
                settledRecent += 1
                if outcome == .onTime { onTimeRecent += 1 }
            }
        }

        return StreakSummary(
            current: run,
            lifetime: lifetime,
            thirtyDayOnTimeRate: settledRecent == 0 ? nil : Double(onTimeRecent) / Double(settledRecent),
            justReset: lastSettled == .missed
        )
    }
}
