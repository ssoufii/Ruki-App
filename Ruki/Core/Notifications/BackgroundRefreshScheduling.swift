import Foundation

/// Wraps the "request the next background wake-up" half of `BGTaskScheduler`
/// so it's fakeable in tests (mirrors why `NotificationScheduling` wraps
/// `UNUserNotificationCenter`, RUKI-013).
///
/// Deliberately does **not** wrap `register(forTaskWithIdentifier:using:
/// launchHandler:)`: that call has to happen at app-launch, attached to a
/// `Scene`, via SwiftUI's `.backgroundTask(.appRefresh(_:))` modifier (the
/// iOS 17+ replacement for manually registering and casting a `BGTask`) —
/// it belongs with the app shell (RUKI T1), not yet built. This protocol
/// covers the part that's real Core logic: deciding *when* to ask for the
/// next wake-up.
protocol BackgroundRefreshScheduling: Sendable {
    /// Requests a background refresh no earlier than `earliestBeginDate`.
    /// iOS gives no delivery guarantee on timing or even that it fires at
    /// all — this is a hint, not a contract. `async` (the real
    /// `BGTaskScheduler.submit` isn't) so an actor-backed fake can conform.
    func submit(identifier: String, earliestBeginDate: Date) async throws
}
