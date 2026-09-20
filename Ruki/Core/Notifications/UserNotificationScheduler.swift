import Foundation
import UserNotifications

/// The real `NotificationScheduling`, wrapping `UNUserNotificationCenter`
/// (RUKI-013). Every request uses a calendar trigger built in
/// `America/Toronto` so the fire time is the Toronto adhan regardless of the
/// device's own time zone (mirrors `TorontoCalendar`, D19).
///
/// `@unchecked Sendable`: `UserNotifications` hasn't audited
/// `UNUserNotificationCenter` for `Sendable` yet, but it's a shared
/// singleton (`.current()`) that apps routinely call from background
/// contexts (e.g. a `BGAppRefreshTask`) without synchronizing access
/// themselves — treating it as safe to hold here matches that usage.
final class UserNotificationScheduler: NotificationScheduling, @unchecked Sendable {
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

    /// A fixed identifier, not `PromptSpec.identifierPrefix`-based: this
    /// isn't a real prompt, so `replacePending`'s clear-and-replace must
    /// never touch it, and a second test prompt should just replace the
    /// first rather than piling up.
    private static let testPromptIdentifier = "ruki.debug.testPrompt"

    func scheduleTestPrompt(secondsFromNow: TimeInterval) async throws {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Ruki test prompt")
        content.body = String(localized: "This fired from the DEBUG tools — no prayer window is attached to it.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, secondsFromNow), repeats: false)
        let request = UNNotificationRequest(identifier: Self.testPromptIdentifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    private func request(for spec: PromptSpec, soundEnabled: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = spec.prayer.displayName
        // R2c: this must not read like every other adhan notification. It names the
        // check-in, and for Fajr says how long there is — with no scolding anywhere.
        content.body = spec.prayer == .fajr
            ? String(localized: "Fajr has begun. Check in whenever you've prayed — you have until sunrise.")
            : String(localized: "\(spec.prayer.displayName) has begun. Check in when you've prayed.")
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
