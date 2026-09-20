import Foundation
import Observation

/// The app's top-level routing decisions: has onboarding been completed, and
/// is a notification-driven check-in pending? `destination` reads
/// `userSettings` live (not a cached copy captured at init), so the future
/// onboarding flow (RUKI-011) flipping `onboardingCompletedAt` moves
/// `RootView` on without this router needing to be told separately.
///
/// `@Observable` so `RootView` re-renders when `pendingCheckInSlotID`
/// changes (RUKI-014) the same way it already does for `destination` via
/// `userSettings`.
@MainActor
@Observable
final class AppRouter {
    enum RootDestination: Equatable {
        case onboarding
        case today
    }

    private let userSettings: UserSettings

    /// Set by `NotificationCoordinator` when a scheduled prompt is tapped.
    /// `RootView` presents that slot's check-in cover over whatever's
    /// currently on screen — no Today-screen stop in between (RUKI-014's
    /// acceptance criterion) — and clears it via `dismissCheckIn()`.
    private(set) var pendingCheckInSlotID: String?

    init(userSettings: UserSettings) {
        self.userSettings = userSettings
    }

    var destination: RootDestination {
        userSettings.onboardingCompletedAt == nil ? .onboarding : .today
    }

    func openCheckIn(forSlotID slotID: String) {
        pendingCheckInSlotID = slotID
    }

    func dismissCheckIn() {
        pendingCheckInSlotID = nil
    }
}
