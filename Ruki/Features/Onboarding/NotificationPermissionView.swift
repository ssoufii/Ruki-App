import SwiftUI

/// RUKI-010: explains Time-Sensitive notifications in plain language
/// *before* the system permission prompt, so the person understands why
/// the app is asking to interrupt Focus/DND before they're asked to decide.
struct NotificationPermissionView: View {
    let viewModel: NotificationPermissionViewModel
    let onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Stay on time")
                .font(.title)
                .foregroundStyle(RukiPalette.primaryText)

            VStack(alignment: .leading, spacing: 16) {
                Text("Ruki sends a notification at the start of each prayer's window, so you know it's open without needing to check.")
                Text("These are marked Time Sensitive, which means they can reach you even if your phone is on Focus or Do Not Disturb — the same way an alarm would. Nothing else in the app uses that.")
            }
            .font(.body)
            .foregroundStyle(RukiPalette.secondaryText)
            .multilineTextAlignment(.leading)
            .padding(.horizontal)

            Spacer()

            Button(action: requestPermission) {
                Text(isRequesting ? "Requesting…" : "Allow notifications")
                    .font(.headline)
                    .foregroundStyle(RukiPalette.background)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .disabled(isRequesting)

            // The app must stay fully usable without notification
            // permission (M1's solo-loop requirement), so declining is a
            // real, unpenalized path forward, not a dead end.
            Button("Not now", action: onContinue)
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)
        }
        .padding(.bottom, 32)
        .background(RukiPalette.background)
    }

    private func requestPermission() {
        isRequesting = true
        Task {
            await viewModel.requestPermission()
            isRequesting = false
            onContinue()
        }
    }
}

#Preview {
    NotificationPermissionView(
        viewModel: NotificationPermissionViewModel(authorizer: SystemNotificationAuthorizer()),
        onContinue: {}
    )
}
