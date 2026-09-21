import SwiftUI

/// Friends' check-ins, newest first. Posts vanish when the next prayer begins
/// (D23), so there is nothing to scroll back through. A post stays locked
/// until you've checked in for the same prayer (D9); the server enforces it.
/// Lateness is never shown here — a friend's timing is not your business.
struct FeedView: View {
    let session: SocialSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !session.isSignedIn {
                    Text("Join a circle to see your friends' check-ins.")
                        .foregroundStyle(RukiPalette.secondaryText)
                } else if session.feed.isEmpty {
                    Text("Nothing here right now. Check-ins from your circle show up until the next prayer begins.")
                        .foregroundStyle(RukiPalette.secondaryText)
                } else {
                    ForEach(session.feed) { post in
                        PostRow(post: post, session: session)
                    }
                }
                if let message = session.message {
                    Text(message).foregroundStyle(RukiPalette.secondaryText)
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { if session.isSignedIn { await session.refreshFeed() } }
            .refreshable { if session.isSignedIn { await session.refreshFeed() } }
        }
    }
}

private struct PostRow: View {
    let post: FeedPost
    let session: SocialSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(post.username) · \(post.prayer.displayName)")
                .font(.headline)
            if post.locked {
                Label("Check in for \(post.prayer.displayName) to see this", systemImage: "lock")
                    .font(.subheadline)
                    .foregroundStyle(RukiPalette.secondaryText)
            } else {
                HStack(spacing: 8) {
                    photo(post.rearPhotoKey)
                    photo(post.frontPhotoKey)
                }
                if let caption = post.caption {
                    Text(caption).font(.subheadline)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private func photo(_ key: String?) -> some View {
        if let url = session.photoURL(key: key) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RukiPalette.surface
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
        }
    }
}
