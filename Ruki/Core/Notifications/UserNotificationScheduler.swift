import Foundation
import UserNotifications

/// The real `NotificationScheduling`, wrapping `UNUserNotificationCenter`
/// (RUKI-013). Every request uses a calendar trigger built in
/// `America/Toronto` so the fire time is the Toronto adhan regardless of the
/// device's own time zone (mirrors `TorontoCalendar`, D19).
final class UserNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func replacePending(with specs: [PromptSpec], soundEnabled: Bool) async throws {
        guard specs.count <= PromptPlanner.maxPending else {
            throw NotificationSchedulingError.tooManyPending(specs.count)
        }

        let ownedIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(PromptSpec.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ownedIdentifiers)

        for spec in specs {
            try await center.add(request(for: spec, soundEnabled: soundEnabled))
        }
    }

    func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    private func request(for spec: PromptSpec, soundEnabled: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = spec.prayer.displayName
        content.body = String(localized: "Time for \(spec.prayer.displayName).")
        content.sound = soundEnabled ? .default : nil
        // Pierces Focus/DND only once the Time Sensitive Notifications
        // capability is added in Xcode (D36) — safe to set unconditionally
        // in code either way.
        content.interruptionLevel = .timeSensitive

        var dateComponents = TorontoCalendar.calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: spec.fireDate
        )
        dateComponents.timeZone = TorontoCalendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        return UNNotificationRequest(identifier: spec.id, content: content, trigger: trigger)
    }
}
