import SwiftUI

/// The onboarding flow `RootView` shows until `userSettings.onboardingCompletedAt`
/// is set: madhab (RUKI-009, partial by design — D31/D34), notification
/// permission (RUKI-010), then intention (RUKI-011) — matching PRD §7.1's
/// order. Add-friends (#12) lands as its own story, adding one more step
/// before completion moves there.
struct OnboardingFlow: View {
    let userSettings: UserSettings
    let clock: any ClockProviding
    let notificationAuthorizer: any NotificationAuthorizing

    private enum Step {
        case madhab
        case notificationPermission
        case intention
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
