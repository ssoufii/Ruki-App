import Foundation
import UserNotifications

/// The real `NotificationAuthorizing`, wrapping `UNUserNotificationCenter`.
final class SystemNotificationAuthorizer: NotificationAuthorizing {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func currentStatus() async -> NotificationAuthorizationStatus {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized: .authorized
        case .denied: .denied
        case .provisional: .provisional
        case .notDetermined, .ephemeral: .notDetermined
        @unknown default: .notDetermined
        }
    }
}
