import Foundation
import Testing
@testable import Ruki

/// The two-friends story against a REAL running `server/ruki_server.py`, through
/// the real `HTTPSocialBackend` and `SocialSession`. Skipped unless a server is
/// given, so CI and normal runs never need one:
///   RUKI_UNLOCK_ALL=1 PORT=8099 python3 server/ruki_server.py
///   TEST_RUNNER_RUKI_TEST_SERVER=http://127.0.0.1:8099 xcodebuild test -only-testing:RukiTests/LiveServerStoryTests ...
@MainActor
@Suite("Live server story", .enabled(if: ProcessInfo.processInfo.environment["RUKI_TEST_SERVER"] != nil))
struct LiveServerStoryTests {
    private func session() -> SocialSession {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let s = SocialSession(defaults: defaults)
        s.serverURLString = ProcessInfo.processInfo.environment["RUKI_TEST_SERVER"] ?? ""
        return s
    }

    @Test("Create, invite, accept, see the friend's check-in, log out and back in")
    func fullStory() async throws {
        let suffix = String(UUID().uuidString.prefix(6)).lowercased()
        let (aName, bName) = ("amina_\(suffix)", "bilal_\(suffix)")
        let alice = session(), bilal = session()

        await alice.register(username: aName, password: "correct horse")
        await bilal.register(username: bName, password: "battery staple")
        #expect(alice.isSignedIn && bilal.isSignedIn, "\(alice.message ?? "") \(bilal.message ?? "")")

        // Alice invites Bilal; the invitation reaches him on his next refresh.
        await alice.addFriend(username: bName)
        #expect(alice.friends.outgoing.map(\.username) == [bName])
        await bilal.refreshQuietly()
        #expect(bilal.pendingInvitations.map(\.username) == [aName])

        // He logs out and back in (the stored token isn't what proves the password).
        bilal.logOut()
        #expect(bilal.needsAccountPrompt)
        await bilal.logIn(username: bName, password: "wrong password")
        #expect(!bilal.isSignedIn)
        await bilal.logIn(username: bName, password: "battery staple")
        #expect(bilal.isSignedIn)
        #expect(bilal.pendingInvitations.map(\.username) == [aName], "the invitation survives a log out")

        // He accepts; both circles now hold each other.
        await bilal.accept(try #require(bilal.pendingInvitations.first))
        #expect(bilal.friends.friends.map(\.username) == [aName])
        await alice.refreshQuietly()
        #expect(alice.friends.friends.map(\.username) == [bName])

        // Alice checks in; Bilal sees it, and can load the photo.
        alice.publish(CheckInUpload(
            prayer: .fajr, slotID: "2026-09-21.fajr", onTimeUntil: Date().addingTimeInterval(1800), retakeCount: 0,
            caption: "Alhamdulillah", expiresAt: Date().addingTimeInterval(3600),
            frontPhoto: Data([0xFF, 0xD8, 0x01]), rearPhoto: Data([0xFF, 0xD8, 0x02])
        ))
        var post: FeedPost?
        for _ in 0..<30 where post == nil {
            await bilal.refreshQuietly()
            post = bilal.feed.first
            if post == nil { try await Task.sleep(for: .milliseconds(100)) }
        }
        let seen = try #require(post, "Bilal never saw Alice's check-in")
        #expect(seen.username == aName && seen.prayer == .fajr)
        #expect(seen.locked == false, "start the server with RUKI_UNLOCK_ALL=1 for this test")
        #expect(seen.caption == "Alhamdulillah")
        let url = try #require(bilal.photoURL(key: seen.rearPhotoKey))
        let (data, response) = try await URLSession.shared.data(from: url)
        #expect((response as? HTTPURLResponse)?.statusCode == 200 && data == Data([0xFF, 0xD8, 0x02]))

        // Clean up so repeated runs leave nothing behind.
        #expect(await alice.deleteAccount())
        #expect(await bilal.deleteAccount())
    }
}
