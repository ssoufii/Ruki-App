import Foundation

/// Wraps `UNUserNotificationCenter` so the notification system is fakeable
/// in tests — critically for the 64-pending-local-notification ceiling
/// (RUKI-016) and DST/dedup behavior.
protocol NotificationScheduling: Sendable {
    /// Replaces every pending Ruki prompt with exactly this set — idempotent,
    /// so a caller never needs to diff against what's already scheduled.
    /// Throws if `specs.count` exceeds iOS's 64-pending ceiling.
    func replacePending(with specs: [PromptSpec], soundEnabled: Bool) async throws

    /// Number of notifications currently pending. Callers must keep this
    /// under iOS's hard ceiling of 64.
    func pendingCount() async -> Int
}

enum NotificationSchedulingError: Error, LocalizedError, Sendable, Equatable {
    /// A hard boundary at the scheduler itself, even though `PromptPlanner`
    /// already caps its output — a scheduler should never trust a caller alone.
    case tooManyPending(Int)

    var errorDescription: String? {
        switch self {
        case .tooManyPending(let count):
            String(
                localized: "Tried to schedule \(count) notifications, over iOS's \(PromptPlanner.maxPending)-pending limit."
            )
        }
    }
}
