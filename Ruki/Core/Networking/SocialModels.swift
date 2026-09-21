import Foundation

// Wire types for the local social backend (D43). Small DTOs, grouped in one
// file on purpose. None of them can carry a missed prayer, a pause, or a
// location: those never leave the device (RDP-2, RDP-3, D8).

struct SocialAccount: Codable, Sendable, Equatable {
    let userID: String
    let username: String
    let token: String
}

struct Friend: Codable, Sendable, Equatable, Identifiable {
    let userID: String
    let username: String
    var id: String { userID }
}

struct FriendsSnapshot: Codable, Sendable, Equatable {
    let cap: Int
    let friends: [Friend]
    let incoming: [Friend]
    let outgoing: [Friend]

    static let empty = FriendsSnapshot(cap: 5, friends: [], incoming: [], outgoing: [])
}

/// One friend's check-in as the server shows it to this viewer. A `locked`
/// post has no caption or photo keys at all (D9): the server, not the app,
/// withholds them until the viewer has checked in for the same prayer.
struct FeedPost: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let username: String
    let prayer: Prayer
    let prayedAt: Date
    let expiresAt: Date
    let locked: Bool
    let caption: String?
    let frontPhotoKey: String?
    let rearPhotoKey: String?
}

/// What the device sends when a check-in is posted. Times the server decides
/// itself (when it was prayed, whether it was late) are deliberately absent —
/// the device clock is not trusted (CLAUDE.md rule 6).
struct CheckInUpload: Codable, Sendable, Equatable {
    let prayer: Prayer
    /// `PrayerSlot.id` (`yyyy-MM-dd.prayer`): the same for every user, whatever their madhab.
    let slotID: String
    /// The server compares its own clock against this to decide `isLate`.
    let onTimeUntil: Date
    let retakeCount: Int
    let caption: String?
    let expiresAt: Date
    let frontPhoto: Data?
    let rearPhoto: Data
}
