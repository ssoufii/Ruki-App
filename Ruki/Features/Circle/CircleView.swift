import SwiftUI

/// Your circle: up to five people, added by username and accepted by both
/// sides. Shows no counts of anyone's activity, only who is in the circle.
struct CircleView: View {
    let session: SocialSession
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var friendUsername = ""

    var body: some View {
        NavigationStack {
            Form {
                if let account = session.account {
                    Section("You") {
                        LabeledContent("Username", value: account.username)
                    }
                    addFriendSection
                    requestsSection
                    circleSection
                } else {
                    signUpSection
                }

                Section {
                    TextField("Server address", text: serverBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    if session.isSignedIn {
                        Button("Forget this account on this device", role: .destructive) { session.signOutLocally() }
                    }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Simulator: http://localhost:8080. On a phone, use your Mac's address, e.g. http://192.168.1.10:8080.")
                }

                if let message = session.message {
                    Section { Text(message).foregroundStyle(RukiPalette.secondaryText) }
                }
            }
            .navigationTitle("Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { if session.isSignedIn { await session.refreshFriends() } }
            .disabled(session.isBusy)
        }
    }

    private var serverBinding: Binding<String> {
        Binding(get: { session.serverURLString }, set: { session.serverURLString = $0 })
    }

    private var signUpSection: some View {
        Section {
            TextField("Choose a username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Create") { Task { await session.register(username: username) } }
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
        } header: {
            Text("Join your circle")
        } footer: {
            Text("Optional. Ruki works fully on your own. Friends only ever see that you checked in — never a missed prayer.")
        }
    }

    private var addFriendSection: some View {
        Section {
            TextField("Friend's username", text: $friendUsername)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Send request") {
                let name = friendUsername
                friendUsername = ""
                Task { await session.addFriend(username: name) }
            }
            .disabled(friendUsername.trimmingCharacters(in: .whitespaces).isEmpty)
        } header: {
            Text("Add someone")
        } footer: {
            Text("\(session.friends.friends.count) of \(session.friends.cap) in your circle.")
        }
    }

    @ViewBuilder private var requestsSection: some View {
        if !session.friends.incoming.isEmpty {
            Section("Requests") {
                ForEach(session.friends.incoming) { friend in
                    HStack {
                        Text(friend.username)
                        Spacer()
                        Button("Accept") { Task { await session.accept(friend) } }
                        Button("Decline", role: .destructive) { Task { await session.remove(friend) } }
                            .foregroundStyle(RukiPalette.secondaryText)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        if !session.friends.outgoing.isEmpty {
            Section("Waiting for a reply") {
                ForEach(session.friends.outgoing) { friend in
                    HStack {
                        Text(friend.username)
                        Spacer()
                        Button("Cancel") { Task { await session.remove(friend) } }
                            .foregroundStyle(RukiPalette.secondaryText)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder private var circleSection: some View {
        if !session.friends.friends.isEmpty {
            Section("Your circle") {
                ForEach(session.friends.friends) { friend in
                    Text(friend.username)
                        .swipeActions {
                            Button("Remove", role: .destructive) { Task { await session.remove(friend) } }
                        }
                }
            }
        }
    }
}
