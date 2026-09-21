import Foundation

/// Everything the app asks of the social backend. A protocol so the session
/// logic is testable against a fake and the real server (a local dev server
/// now, D43; Supabase later) is swappable.
protocol SocialBackend: Sendable {
    func register(username: String, password: String) async throws -> SocialAccount
    func login(username: String, password: String) async throws -> SocialAccount
    func friends() async throws -> FriendsSnapshot
    func requestFriend(username: String) async throws
    func acceptFriend(userID: String) async throws
    /// Decline, cancel and unfriend are the same operation server-side.
    func removeFriend(userID: String) async throws
    func publish(_ upload: CheckInUpload) async throws
    func feed() async throws -> [FeedPost]
    func deleteAccount() async throws
    func photoURL(key: String) -> URL?
}

enum SocialError: LocalizedError, Equatable {
    case notSignedIn
    case unreachable
    case server(code: String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            String(localized: "Choose a username first.")
        case .unreachable:
            String(localized: "Couldn't reach the server. Check the address and that it's running.")
        case .server(let code):
            switch code {
            case "circle_full": String(localized: "Your circle is full — five people at most.")
            case "their_circle_full": String(localized: "Their circle is full.")
            case "no_such_user": String(localized: "No one has that username.")
            case "username_taken": String(localized: "That username is taken.")
            case "invalid_credentials": String(localized: "That username and password don't match.")
            case "weak_password": String(localized: "Use at least 8 characters for your password.")
            case "invalid_username": String(localized: "Use 3–20 letters, numbers or underscores.")
            case "cannot_add_self": String(localized: "That's you.")
            case "unauthorized": String(localized: "This account isn't known to the server. Reset it in Circle.")
            default: String(localized: "Something went wrong. Please try again.")
            }
        }
    }
}
