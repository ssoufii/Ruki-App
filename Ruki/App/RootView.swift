import SwiftUI

/// The one view `RukiApp` shows. Routes between onboarding and the app's
/// main flow; each branch is a placeholder until its own story (RUKI-011,
/// T2) builds the real screen.
struct RootView: View {
    let environment: AppEnvironment

    var body: some View {
        Group {
            switch environment.router.destination {
            case .onboarding:
                PlaceholderScreen(title: "Onboarding")
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
