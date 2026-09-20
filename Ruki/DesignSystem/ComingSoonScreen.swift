import SwiftUI

/// Stands in for a destination its own story hasn't built yet (T1 used this
/// shape inline for `RootView`'s `.today` case before T2 built the real
/// screen). An honest placeholder rather than a dead tap target: the user
/// sees exactly what state the app is in, never a silent no-op.
struct ComingSoonScreen: View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RukiPalette.background)
    }
}

#Preview {
    ComingSoonScreen(title: "Pause")
}
