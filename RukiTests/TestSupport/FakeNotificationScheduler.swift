import Foundation
@testable import Ruki

/// In-memory `NotificationScheduling` fake. Tracks pending windows so tests
/// can assert on the 64-notification ceiling and dedup behavior without
/// touching `UNUserNotificationCenter`.
actor FakeNotificationScheduler: NotificationScheduling {
    private(set) var scheduled: [PrayerWindow] = []

    func scheduleNotification(for window: PrayerWindow) async throws {
        scheduled.append(window)
    }

    func cancelAllPending() async {
        scheduled.removeAll()
    }

    func pendingCount() async -> Int {
        scheduled.count
    }
}
