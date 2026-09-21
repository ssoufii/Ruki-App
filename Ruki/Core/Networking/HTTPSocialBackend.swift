import Foundation

/// Talks to `server/ruki_server.py`. Plain JSON over HTTP with a bearer token;
/// dates travel as Unix seconds. Local-network only (D43) — there is no TLS,
/// so this must be replaced, not hardened, before anything leaves a dev machine.
struct HTTPSocialBackend: SocialBackend {
    let baseURL: URL
    let token: String?
    var session: URLSession = .shared

    // MARK: SocialBackend

    func register(username: String) async throws -> SocialAccount {
        try await send("POST", "/register", body: ["username": username])
    }

    func friends() async throws -> FriendsSnapshot {
        try await send("GET", "/friends")
    }

    func requestFriend(username: String) async throws {
        let _: Ack = try await send("POST", "/friends/request", body: ["username": username])
    }

    func acceptFriend(userID: String) async throws {
        let _: Ack = try await send("POST", "/friends/accept", body: ["userID": userID])
    }

    func removeFriend(userID: String) async throws {
        let _: Ack = try await send("POST", "/friends/remove", body: ["userID": userID])
    }

    func publish(_ upload: CheckInUpload) async throws {
        let _: Ack = try await send("POST", "/checkins", body: upload)
    }

    func feed() async throws -> [FeedPost] {
        let response: FeedResponse = try await send("GET", "/feed")
        return response.posts
    }

    func deleteAccount() async throws {
        let _: Ack = try await send("POST", "/account/delete", body: [String: String]())
    }

    /// The token rides in the query because `AsyncImage` can't set headers.
    /// Acceptable on a local dev server; not on a real one.
    func photoURL(key: String) -> URL? {
        guard let token else { return nil }
        var components = URLComponents(url: baseURL.appendingPathComponent("photos/\(key)"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        return components?.url
    }

    // MARK: Transport

    private struct Ack: Decodable { let status: String }
    private struct FeedResponse: Decodable { let posts: [FeedPost] }
    private struct ErrorResponse: Decodable { let error: String }

    private func send<Response: Decodable>(_ method: String, _ path: String, body: (some Encodable)? = Optional<String>.none) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: 30)
        request.httpMethod = method
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SocialError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw SocialError.unreachable }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error ?? "server_error"
            throw SocialError.server(code: code)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw SocialError.server(code: "bad_response")
        }
    }
}
