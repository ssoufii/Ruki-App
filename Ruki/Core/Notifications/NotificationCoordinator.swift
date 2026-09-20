import Foundation
import UserNotifications

/// RUKI-014: bridges `UNUserNotificationCenterDelegate` callbacks to the
/// app's routing state so tapping a prompt opens directly to that prayer's
/// check-in screen — no home screen or interstitial between intent and
/// action.
///
/// `@unchecked Sendable` for the same reason as `UserNotificationScheduler`:
/// `UNUserNotificationCenterDelegate` isn't `Sendable`-audited, and this type
/// holds no mutable state of its own beyond the `@MainActor`-isolated
/// `AppRouter` it forwards into.
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    /// A tap (or any non-dismiss interaction) on one of this app's own
    /// prompts routes straight to that slot's check-in. Notifications this
    /// app didn't schedule — identifiers without the `ruki.prompt.` prefix,
    /// were this delegate ever handed one — are ignored rather than routed.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let slotID = Self.slotID(fromRequestIdentifier: response.notification.request.identifier) {
            Task { @MainActor [router] in
                router.openCheckIn(forSlotID: slotID)
            }
        }
        completionHandler()
    }

    /// Without this, a prompt that fires while the app is already open is
    /// silently swallowed by default. Presenting it as a banner with sound
    /// matches what the user would have seen backgrounded, and tapping it
    /// still routes via `didReceive` above.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// A `PromptSpec.id` is `"\(PromptSpec.identifierPrefix)\(slot.id)"`
    /// (see `PromptSpec.init`); this is the inverse. Pure and `static` so it
    /// can be unit-tested without constructing a `UNNotificationResponse`,
    /// which has no public initializer.
    static func slotID(fromRequestIdentifier identifier: String) -> String? {
        guard identifier.hasPrefix(PromptSpec.identifierPrefix) else { return nil }
        let slotID = String(identifier.dropFirst(PromptSpec.identifierPrefix.count))
        return slotID.isEmpty ? nil : slotID
    }
}
