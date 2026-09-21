import Foundation
import Observation

/// The app's single view of the social layer: who I am on the server, my
/// circle, and the feed. Optional by design — the app is fully usable with no
/// account (R7), and nothing here is ever required for a check-in.
@MainActor
@Observable
final class SocialSession: CheckInPublishing {
    static let defaultServerURL = "http://localhost:8080"

    private(set) var account: SocialAccount?
    private(set) var friends = FriendsSnapshot.empty
    private(set) var feed: [FeedPost] = []
    private(set) var isBusy = false
    /// The last failure, already worded for a person. Cleared by the next action.
    private(set) var message: String?

    /// Editable in Circle: a phone reaches the Mac by its LAN address, the Simulator by localhost.
    var serverURLString: String {
        didSet { defaults.set(serverURLString, forKey: Keys.serverURL) }
    }

    var isSignedIn: Bool { account != nil }

    private let defaults: UserDefaults
    private let makeBackend: @Sendable (URL, String?) -> any SocialBackend

    private enum Keys {
        static let account = "social.account"
        static let serverURL = "social.serverURL"
    }

    /// The token sits in `UserDefaults`, not the Keychain: it only unlocks a
    /// local dev server (D43). Move it to the Keychain with the real backend.
    init(
        defaults: UserDefaults = .standard,
        makeBackend: @escaping @Sendable (URL, String?) -> any SocialBackend = { HTTPSocialBackend(baseURL: $0, token: $1) }
    ) {
        self.defaults = defaults
        self.makeBackend = makeBackend
        self.serverURLString = defaults.string(forKey: Keys.serverURL) ?? Self.defaultServerURL
        if let data = defaults.data(forKey: Keys.account) {
            account = try? JSONDecoder().decode(SocialAccount.self, from: data)
        }
    }

    // MARK: Account

    func register(username: String) async {
        await perform { backend in
            let account = try await backend.register(username: username.trimmingCharacters(in: .whitespaces))
            self.setAccount(account)
        }
        await refreshFriends()
    }

    /// Forget the account on this device only (e.g. after wiping the server's data folder).
    func signOutLocally() {
        setAccount(nil)
        friends = .empty
        feed = []
    }

    /// Deletes the account and everything it posted from the server. Returns
    /// `false`, having changed nothing, if the server can't be reached — the
    /// same rule as the on-device wipe: never report data gone while it isn't.
    func deleteAccount() async -> Bool {
        guard isSignedIn else { return true }
        guard let backend = backend() else { return false }
        do {
            try await backend.deleteAccount()
            signOutLocally()
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    // MARK: Circle

    func refreshFriends() async {
        await perform { self.friends = try await $0.friends() }
    }

    func addFriend(username: String) async {
        await perform { try await $0.requestFriend(username: username.trimmingCharacters(in: .whitespaces).lowercased()) }
        await refreshFriends()
    }

    func accept(_ friend: Friend) async {
        await perform { try await $0.acceptFriend(userID: friend.userID) }
        await refreshFriends()
    }

    func remove(_ friend: Friend) async {
        await perform { try await $0.removeFriend(userID: friend.userID) }
        await refreshFriends()
    }

    // MARK: Feed

    func refreshFeed() async {
        await perform { self.feed = try await $0.feed() }
    }

    func photoURL(key: String?) -> URL? {
        key.flatMap { backend()?.photoURL(key: $0) }
    }

    // MARK: CheckInPublishing

    func publish(_ upload: CheckInUpload) {
        guard isSignedIn, let backend = backend() else { return }
        Task { try? await backend.publish(upload) }
    }

    // MARK: Private

    private func backend() -> (any SocialBackend)? {
        URL(string: serverURLString.trimmingCharacters(in: .whitespaces)).map { makeBackend($0, account?.token) }
    }

    private func setAccount(_ account: SocialAccount?) {
        self.account = account
        defaults.set(account.flatMap { try? JSONEncoder().encode($0) }, forKey: Keys.account)
    }

    private func perform(_ work: (any SocialBackend) async throws -> Void) async {
        guard let backend = backend() else {
            message = SocialError.unreachable.localizedDescription
            return
        }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            try await work(backend)
        } catch {
            message = error.localizedDescription
        }
    }
}
