import SwiftUI

/// What a tapped prompt shows (RUKI-014): the real check-in flow when there's
/// one to do, otherwise a short, warm note. Never scolding — a closed window
/// is stated plainly and pointed at what's still possible.
struct PendingCheckInView: View {
    @State private var route: CheckInRouteResolver.Route
    @Environment(\.dismiss) private var dismiss

    /// Resolved once, when the cover is presented. `@State` keeps the same
    /// `CheckInViewModel` alive across re-renders of the view that presents this.
    init(route: CheckInRouteResolver.Route) {
        _route = State(initialValue: route)
    }

    var body: some View {
        switch route {
        case .flow(let viewModel):
            CheckInFlowView(viewModel: viewModel)
        case .alreadyCheckedIn(let prayer):
            note(String(localized: "You've already checked in for \(prayer.displayName)."))
        case .windowClosed(let prayer):
            note(String(localized: "\(prayer.displayName)'s window has ended. If you prayed, you can note it privately from Today."))
        case .notYetOpen(let prayer):
            note(String(localized: "\(prayer.displayName) hasn't begun yet."))
        case .unknown:
            note(String(localized: "That prayer isn't available any more."))
        }
    }

    private func note(_ message: String) -> some View {
        VStack(spacing: 24) {
            Text(message)
                .font(.title3)
                .foregroundStyle(RukiPalette.primaryText)
                .multilineTextAlignment(.center)
            Button("OK") { dismiss() }
                .font(.headline)
                .foregroundStyle(RukiPalette.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RukiPalette.background)
    }
}
