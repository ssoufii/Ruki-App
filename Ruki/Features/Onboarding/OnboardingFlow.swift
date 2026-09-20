import SwiftUI

/// The onboarding flow `RootView` shows until `userSettings.onboardingCompletedAt`
/// is set: madhab (RUKI-009, partial by design — D31/D34) then intention
/// (RUKI-011). Notification permission (#10) and add-friends (#12) land as
/// their own stories, adding further steps before completion moves to the
/// last of them.
struct OnboardingFlow: View {
    let userSettings: UserSettings
    let clock: any ClockProviding

    private enum Step {
        case madhab
        case intention
    }

    @State private var step: Step = .madhab

    var body: some View {
        switch step {
        case .madhab:
            MadhabSelectionView(madhab: madhabBinding) {
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
    OnboardingFlow(userSettings: UserSettings(), clock: SystemClock())
}
