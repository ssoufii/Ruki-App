import SwiftUI

/// The one view `RukiApp` shows. Routes between onboarding (RUKI-011) and
/// the app's main flow (T2's Today screen).
struct RootView: View {
    let environment: AppEnvironment

    var body: some View {
        Group {
            switch environment.router.destination {
            case .onboarding:
                OnboardingFlow(
                    userSettings: environment.userSettings,
                    clock: environment.clock,
                    notificationAuthorizer: environment.notificationAuthorizer
                )
            case .today:
                TodayView(
                    timeline: environment.timeline,
                    clock: environment.clock,
                    userSettings: environment.userSettings,
                    historyStore: environment.historyStore,
                    onPauseChanged: { await environment.refreshBackgroundSchedule() }
                )
            }
        }
        .background(RukiPalette.background)
    }
}

#Preview {
    RootView(environment: AppEnvironment())
}
