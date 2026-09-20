import Foundation

/// Turns a set of upcoming prayer slots into the notifications to schedule.
/// Pure: given slots and which prayers are enabled, produces at most
/// `maxPending` specs so a caller can never even attempt to schedule past
/// iOS's ceiling (RUKI-016).
struct PromptPlanner: Sendable {
    static let maxPending = 64

    nonisolated func plan(for slots: [PrayerSlot], enabledPrayers: Set<Prayer> = Set(Prayer.allCases)) -> [PromptSpec] {
        slots
            .filter { enabledPrayers.contains($0.prayer) }
            .sorted { $0.window.start < $1.window.start }
            .prefix(Self.maxPending)
            .map(PromptSpec.init)
    }
}
