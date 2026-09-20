import Foundation

enum NotificationAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
}

/// Wraps `UNUserNotificationCenter`'s permission surface so it's fakeable in tests.
protocol NotificationAuthorizing: Sendable {
    /// Prompts the system permission dialog if not yet determined. Returns
    /// whether the user granted it.
    func requestAuthorization() async throws -> Bool

    func currentStatus() async -> NotificationAuthorizationStatus
}
