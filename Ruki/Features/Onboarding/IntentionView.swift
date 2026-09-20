import SwiftUI

/// RUKI-011: an explicit screen about intention (*niyyah*) and the risk of
/// riya' (RDP-1), shown once, before any social feature is reachable.
///
/// This copy is a launch gate for scholar review (PRD OQ-1) — it isn't a
/// fiqh ruling, just an honest description of what the app does and
/// doesn't see.
struct IntentionView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Before you begin")
                .font(.title)
                .foregroundStyle(RukiPalette.primaryText)

            VStack(alignment: .leading, spacing: 16) {
                Text("Ruki is here to help you show up for prayer — not to put your worship on display.")
                Text("Your history and your streak are yours alone. No one else ever sees them. If you add friends later, what they see is only that you showed up — never a ranking, never a count.")
                Text("Set your intention now: this is between you and Allah. The app is just a nudge.")
            }
            .font(.body)
            .foregroundStyle(RukiPalette.secondaryText)
            .multilineTextAlignment(.leading)
            .padding(.horizontal)

            Spacer()

            Button(action: onContinue) {
                Text("I showed up. Let's begin.")
                    .font(.headline)
                    .foregroundStyle(RukiPalette.background)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding(.bottom, 32)
        .background(RukiPalette.background)
    }
}

#Preview {
    IntentionView(onContinue: {})
}
