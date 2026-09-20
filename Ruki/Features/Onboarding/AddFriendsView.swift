import SwiftUI

/// RUKI-012: the last onboarding step, and the only one that mentions
/// friends at all. Ruki has no friend-adding mechanism in M1 — Circle is
/// M2 (CLAUDE.md: the app must be fully usable solo, with no backend,
/// before any social code exists) — so "Add friends" opens
/// `ComingSoonScreen`, the same honest-placeholder pattern used elsewhere
/// for a destination whose story hasn't landed. "Skip for now" is the one
/// fully-working path here, and it does exactly what "Add friends" would
/// also eventually fall through to: onboarding completes either way.
struct AddFriendsView: View {
    let onContinue: () -> Void

    @State private var showingAddFriends = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Friends are optional")
                .font(.title)
                .foregroundStyle(RukiPalette.primaryText)

            VStack(alignment: .leading, spacing: 16) {
                Text("Ruki works completely on your own. Your prompts, your streak, and your history don't need anyone else.")
                Text("Later, you can add up to five people to share only that you showed up — never a ranking, never a count.")
            }
            .font(.body)
            .foregroundStyle(RukiPalette.secondaryText)
            .multilineTextAlignment(.leading)
            .padding(.horizontal)

            Spacer()

            Button {
                showingAddFriends = true
            } label: {
                Text("Add friends")
                    .font(.headline)
                    .foregroundStyle(RukiPalette.background)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // The one path that actually works end-to-end in M1 (RUKI-012):
            // the app must be fully usable with zero friends.
            Button("Skip for now", action: onContinue)
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)
        }
        .padding(.bottom, 32)
        .background(RukiPalette.background)
        .sheet(isPresented: $showingAddFriends) {
            ComingSoonScreen(title: "Add friends")
        }
    }
}

#Preview {
    AddFriendsView(onContinue: {})
}
