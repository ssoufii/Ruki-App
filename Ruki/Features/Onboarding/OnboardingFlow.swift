import SwiftUI

/// The onboarding flow `RootView` shows until `userSettings.onboardingCompletedAt`
/// is set. Currently just the intention screen (RUKI-011) — madhab (#9),
/// notification permission (#10), and add-friends (#12) land as their own
/// stories add further steps before completion moves to the last of them.
struct OnboardingFlow: View {
    let userSettings: UserSettings
    let clock: any ClockProviding

    var body: some View {
        IntentionView {
            userSettings.onboardingCompletedAt = clock.now()
        }
    }
}

#Preview {
    OnboardingFlow(userSettings: UserSettings(), clock: SystemClock())
}
