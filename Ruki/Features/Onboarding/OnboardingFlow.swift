import SwiftUI

/// The onboarding flow `RootView` shows until `userSettings.onboardingCompletedAt`
/// is set: madhab (RUKI-009, partial by design — D31/D34), notification
/// permission (RUKI-010), intention (RUKI-011), then add-friends (RUKI-012)
/// — matching PRD §7.1's order. Add-friends is last and its "Skip for now"
/// path is what actually completes onboarding; there's no real add-friend
/// mechanism in M1 (Circle is M2), so the app must reach `.today` with zero
/// friends every time.
struct OnboardingFlow: View {
    let userSettings: UserSettings
    let clock: any ClockProviding
    let notificationAuthorizer: any NotificationAuthorizing

    private enum Step {
        case madhab
        case notificationPermission
        case intention
        case addFriends
    }

    @State private var step: Step = .madhab

    var body: some View {
        switch step {
        case .madhab:
            MadhabSelectionView(madhab: madhabBinding) {
                step = .notificationPermission
            }
        case .notificationPermission:
            NotificationPermissionView(
                viewModel: NotificationPermissionViewModel(authorizer: notificationAuthorizer)
            ) {
                step = .intention
            }
        case .intention:
            IntentionView {
                step = .addFriends
            }
        case .addFriends:
            AddFriendsView {
                userSettings.onboardingCompletedAt = clock.now()
            }
        }
    }

    private var madhabBinding: Binding<Madhab> {
        Binding(
            get: { userSettings.madhab },
            set: { userSettings.madhab = $0 }
        )
    }
}

#Preview {
    OnboardingFlow(userSettings: UserSettings(), clock: SystemClock(), notificationAuthorizer: SystemNotificationAuthorizer())
}
