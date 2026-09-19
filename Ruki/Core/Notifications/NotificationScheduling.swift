import Foundation

/// Wraps `UNUserNotificationCenter` (and, once Epic 09 lands, the push side)
/// so the notification system is fakeable in tests — critically for the
/// 64-pending-local-notification ceiling (RUKI-016) and DST/dedup behavior.
protocol NotificationScheduling: Sendable {
    /// Schedules a Time-Sensitive local notification firing at `window.start`.
    func scheduleNotification(for window: PrayerWindow) async throws

    /// Cancels every notification this scheduler has pending.
    func cancelAllPending() async

    /// Number of notifications currently pending. Callers must keep this
    /// under iOS's hard ceiling of 64.
    func pendingCount() async -> Int
}
