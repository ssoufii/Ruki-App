import Foundation

/// The only check-in fields a friend is ever allowed to read (PRD §10.3).
///
/// There is no `pausedUntil`, no missed-prayer field, and no location —
/// those never leave the device (RDP-2, RDP-3, D8). A field belongs here
/// only if a friend is meant to see it; anything private lives in
/// `CheckInRecord`/`PrayerMark`/`PauseRecord` instead, which this type has
/// no path to.
struct FriendFacingCheckIn: Codable, Sendable, Equatable {
    let id: String
    let userID: String
    let prayer: Prayer
    let prayedAt: Date
    let promptedAt: Date
    let isLate: Bool
    let retakeCount: Int
    let caption: String?
    let frontPhotoKey: String?
    let rearPhotoKey: String
    /// Start of the next prayer (D23) — when this post (and its photos) disappear.
    let expiresAt: Date
}
