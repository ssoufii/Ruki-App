import Foundation
import SwiftData

/// A private "I prayed" / "I didn't" mark on a closed prayer window (RUKI-026).
/// On-device only — never part of any friend-facing payload.
@Model
final class PrayerMark {
    @Attribute(.unique) var slotID: String
    /// Raw value of `MarkSnapshot.Kind`.
    var kindRawValue: String
    var markedAt: Date

    init(slotID: String, kindRawValue: String, markedAt: Date) {
        self.slotID = slotID
        self.kindRawValue = kindRawValue
        self.markedAt = markedAt
    }
}
