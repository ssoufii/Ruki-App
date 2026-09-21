import Foundation
import Testing
@testable import Ruki

private struct FakeSocialBackend: SocialBackend {
    var failDelete = false
    var rejectSession = false
    var incoming: [Friend] = []

    func register(username: String, password: String) async throws -> SocialAccount {
        SocialAccount(userID: "u1", username: username, token: "t")
    }
    func login(username: String, password: String) async throws -> SocialAccount {
        if password != "right-password" { throw SocialError.server(code: "invalid_credentials") }
        return SocialAccount(userID: "u1", username: username, token: "t")
    }
    func friends() async throws -> FriendsSnapshot {
        if rejectSession { throw SocialError.server(code: "unauthorized") }
        return FriendsSnapshot(cap: 5, friends: [], incoming: incoming, outgoing: [])
    }
    func requestFriend(username: String) async throws { throw SocialError.server(code: "no_such_user") }
    func acceptFriend(userID: String) async throws {}
    func removeFriend(userID: String) async throws {}
    func publish(_ upload: CheckInUpload) async throws {}
    func feed() async throws -> [FeedPost] { [] }
    func deleteAccount() async throws { if failDelete { throw SocialError.unreachable } }
    func photoURL(key: String) -> URL? { nil }
}

@MainActor
@Suite("SocialSession")
struct SocialSessionTests {
    private func session(failDelete: Bool = false) -> SocialSession {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return SocialSession(defaults: defaults, makeBackend: { _, _ in FakeSocialBackend(failDelete: failDelete) })
    }

    @Test("Registering signs in, and the account survives a relaunch")
    func registerPersists() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let first = SocialSession(defaults: defaults, makeBackend: { _, _ in FakeSocialBackend() })
        await first.register(username: "salim", password: "right-password")
        #expect(first.account?.username == "salim")
        #expect(SocialSession(defaults: defaults).account?.username == "salim")
    }

    @Test("A failed server delete changes nothing and reports failure")
    func failedDeleteKeepsAccount() async {
        let s = session(failDelete: true)
        await s.register(username: "salim", password: "right-password")
        #expect(await s.deleteAccount() == false)
        #expect(s.isSignedIn)
    }

    @Test("A successful delete signs out; with no account there is nothing to delete")
    func deleteSignsOut() async {
        let s = session()
        #expect(await s.deleteAccount())
        await s.register(username: "salim", password: "right-password")
        #expect(await s.deleteAccount())
        #expect(!s.isSignedIn)
    }

    @Test("A wrong password leaves you logged out with a plain message; logging out then in restores the account")
    func loginAndLogout() async {
        let s = session()
        await s.logIn(username: "salim", password: "nope")
        #expect(!s.isSignedIn)
        #expect(s.message == SocialError.server(code: "invalid_credentials").localizedDescription)

        await s.logIn(username: "salim", password: "right-password")
        #expect(s.isSignedIn)
        s.logOut()
        #expect(!s.isSignedIn)
    }

    @Test("A failed friend request keeps its error message (the follow-up refresh must not wipe it)")
    func failedRequestKeepsMessage() async {
        let s = session()
        await s.logIn(username: "salim", password: "right-password")
        await s.addFriend(username: "ghost")
        #expect(s.message == SocialError.server(code: "no_such_user").localizedDescription)
    }

    @Test("An invitation arrives through the quiet refresh, without touching busy state or messages")
    func invitationArrives() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let invite = Friend(userID: "u2", username: "bilal")
        let s = SocialSession(defaults: defaults, makeBackend: { _, _ in FakeSocialBackend(incoming: [invite]) })
        await s.logIn(username: "salim", password: "right-password")
        #expect(s.pendingInvitations == [invite])
        #expect(!s.isBusy && s.message == nil)
    }

    @Test("Skipping the launch prompt sticks until you log out, then the prompt returns")
    func skipAndLogOut() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let s = SocialSession(defaults: defaults, makeBackend: { _, _ in FakeSocialBackend() })
        #expect(s.needsAccountPrompt)
        s.continueWithoutAccount()
        #expect(!s.needsAccountPrompt)
        #expect(!SocialSession(defaults: defaults).needsAccountPrompt)   // remembered across launches

        await s.logIn(username: "salim", password: "right-password")
        s.logOut()
        #expect(s.needsAccountPrompt)
    }

    @Test("A login the server no longer recognises logs out with a plain message")
    func expiredSessionLogsOut() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let s = SocialSession(defaults: defaults, makeBackend: { _, _ in FakeSocialBackend(rejectSession: true) })
        await s.logIn(username: "salim", password: "right-password")
        #expect(!s.isSignedIn)
        #expect(s.needsAccountPrompt)
    }
}
