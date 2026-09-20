import SwiftUI

/// The one view `RukiApp` shows. Routes between onboarding (RUKI-011) and
/// the app's main flow — `.today` is still a placeholder until T2 builds
/// the real Today screen.
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
                PlaceholderScreen(title: "Today")
            }
        }
        .background(RukiPalette.background)
    }
}

/// Stands in for a screen its own story hasn't built yet.
private struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2)
                .foregroundStyle(RukiPalette.primaryText)
            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)
        }
    }
}

#Preview {
    RootView(environment: AppEnvironment())
}
