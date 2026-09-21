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
    /// The person chose "Continue without an account". Cleared by logging out,
    /// so logging out always brings the login screen back.
    private(set) var declinedAccount: Bool

    /// Editable in Circle: a phone reaches the Mac by its LAN address, the Simulator by localhost.
    var serverURLString: String {
        didSet { defaults.set(serverURLString, forKey: Keys.serverURL) }
    }

    var isSignedIn: Bool { account != nil }
    /// Whether launch should show the login screen: not signed in, and hasn't opted out.
    var needsAccountPrompt: Bool { !isSignedIn && !declinedAccount }
    /// Requests waiting on this person — what the Today invitation cards and the Circle badge read.
    var pendingInvitations: [Friend] { friends.incoming }

    private let defaults: UserDefaults
    private let makeBackend: @Sendable (URL, String?) -> any SocialBackend

    private enum Keys {
        static let account = "social.account"
        static let serverURL = "social.serverURL"
        static let declined = "social.declinedAccount"
    }

    /// The login token sits in `UserDefaults`, not the Keychain: it only
    /// unlocks a local dev server (D43). Move it to the Keychain with the real
    /// backend. The password itself is never stored — the token is what keeps
    /// the person logged in across launches.
    init(
        defaults: UserDefaults = .standard,
        makeBackend: @escaping @Sendable (URL, String?) -> any SocialBackend = { HTTPSocialBackend(baseURL: $0, token: $1) }
    ) {
        self.defaults = defaults
        self.makeBackend = makeBackend
        self.serverURLString = defaults.string(forKey: Keys.serverURL) ?? Self.defaultServerURL
        self.declinedAccount = defaults.bool(forKey: Keys.declined)
        if let data = defaults.data(forKey: Keys.account) {
            account = try? JSONDecoder().decode(SocialAccount.self, from: data)
        }
    }

    // MARK: Account

    func register(username: String, password: String) async {
        await perform { backend in
            self.setAccount(try await backend.register(username: username.trimmingCharacters(in: .whitespaces), password: password))
        }
        await refreshQuietly()
    }

    func logIn(username: String, password: String) async {
        await perform { backend in
            self.setAccount(try await backend.login(username: username.trimmingCharacters(in: .whitespaces), password: password))
        }
        await refreshQuietly()
    }

    /// "Continue without an account" on the launch prompt. Ruki works fully solo (R7).
    func continueWithoutAccount() {
        declinedAccount = true
        defaults.set(true, forKey: Keys.declined)
    }

    /// Log out of this device. The account and its circle stay on the server;
    /// logging back in restores them. Brings the login screen back.
    func logOut() {
        setAccount(nil)
        friends = .empty
        feed = []
        declinedAccount = false
        defaults.set(false, forKey: Keys.declined)
    }

    /// Deletes the account and everything it posted from the server. Returns
    /// `false`, having changed nothing, if the server can't be reached — the
    /// same rule as the on-device wipe: never report data gone while it isn't.
    func deleteAccount() async -> Bool {
        guard isSignedIn else { return true }
        guard let backend = backend() else { return false }
        do {
            try await backend.deleteAccount()
            logOut()
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
        await refreshQuietly()
    }

    func accept(_ friend: Friend) async {
        await perform { try await $0.acceptFriend(userID: friend.userID) }
        await refreshQuietly()
    }

    func remove(_ friend: Friend) async {
        await perform { try await $0.removeFriend(userID: friend.userID) }
        await refreshQuietly()
    }

    // MARK: Feed

    func refreshFeed() async {
        await perform { self.feed = try await $0.feed() }
    }

    func photoURL(key: String?) -> URL? {
        key.flatMap { backend()?.photoURL(key: $0) }
    }

    // MARK: Background refresh

    /// Re-reads the circle and feed without touching `isBusy` or `message`, so
    /// a poll never flickers a form or wipes an error the person is reading.
    /// This is how an invitation "arrives": Today calls it on appear, on
    /// foreground and every minute. A real push needs the real backend (D43).
    func refreshQuietly() async {
        guard let token = account?.token, let backend = backend() else { return }
        do {
            let latestFriends = try await backend.friends()
            let latestFeed = try await backend.feed()
            // The person may have logged out or switched account while this was in flight.
            guard account?.token == token else { return }
            friends = latestFriends
            feed = latestFeed
        } catch {
            handleSessionExpiry(error, for: token)
        }
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

    /// A 401 means the server no longer knows this login (its data was reset,
    /// or the account was deleted elsewhere). Say so and show the login screen
    /// rather than leaving every action failing.
    private func handleSessionExpiry(_ error: Error, for token: String) {
        guard error as? SocialError == .server(code: "unauthorized"), account?.token == token else { return }
        logOut()
        message = String(localized: "You've been logged out. Please log in again.")
    }

    private func perform(_ work: (any SocialBackend) async throws -> Void) async {
        guard let backend = backend() else {
            message = SocialError.unreachable.localizedDescription
            return
        }
        let token = account?.token
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            try await work(backend)
        } catch {
            message = error.localizedDescription
            if let token { handleSessionExpiry(error, for: token) }
        }
    }
}
