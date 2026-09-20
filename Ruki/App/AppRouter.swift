import Foundation

/// The app's one top-level routing decision: has onboarding been completed?
/// `destination` reads `userSettings` live (not a cached copy captured at
/// init), so the future onboarding flow (RUKI-011) flipping
/// `onboardingCompletedAt` moves `RootView` on without this router needing
/// to be told separately.
@MainActor
final class AppRouter {
    enum RootDestination: Equatable {
        case onboarding
        case today
    }

    private let userSettings: UserSettings

    init(userSettings: UserSettings) {
        self.userSettings = userSettings
    }

    var destination: RootDestination {
        userSettings.onboardingCompletedAt == nil ? .onboarding : .today
    }
}
