import Foundation
import Testing
@testable import Ruki

private struct FakeSocialBackend: SocialBackend {
    var failDelete = false

    func register(username: String) async throws -> SocialAccount {
        SocialAccount(userID: "u1", username: username, token: "t")
    }
    func friends() async throws -> FriendsSnapshot { .empty }
    func requestFriend(username: String) async throws {}
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
        await first.register(username: "salim")
        #expect(first.account?.username == "salim")
        #expect(SocialSession(defaults: defaults).account?.username == "salim")
    }

    @Test("A failed server delete changes nothing and reports failure")
    func failedDeleteKeepsAccount() async {
        let s = session(failDelete: true)
        await s.register(username: "salim")
        #expect(await s.deleteAccount() == false)
        #expect(s.isSignedIn)
    }

    @Test("A successful delete signs out; with no account there is nothing to delete")
    func deleteSignsOut() async {
        let s = session()
        #expect(await s.deleteAccount())
        await s.register(username: "salim")
        #expect(await s.deleteAccount())
        #expect(!s.isSignedIn)
    }
}
