import Foundation
import SwiftData

/// One completed check-in for a single prayer slot. Kept forever (D26): the
/// photo is purged at `expiresAt`, but this record — the fact of having
/// prayed — never is.
///
/// Enum-shaped fields are stored as their raw `String` so a future case
/// change to `Prayer` doesn't require a SwiftData migration for old rows.
@Model
final class CheckInRecord {
    @Attribute(.unique) var slotID: String
    var dayKey: String
    var prayerRawValue: String
    var isLate: Bool
    var checkedInAt: Date
    /// `nil` for Space Only captures. Purged independently at `expiresAt` (D37).
    var frontImageData: Data?
    var rearImageData: Data?
    /// When the next prayer begins (D23/D37) — the moment the photo(s) purge.
    var expiresAt: Date

    init(
        slotID: String,
        dayKey: String,
        prayerRawValue: String,
        isLate: Bool,
        checkedInAt: Date,
        frontImageData: Data?,
        rearImageData: Data?,
        expiresAt: Date
    ) {
        self.slotID = slotID
        self.dayKey = dayKey
        self.prayerRawValue = prayerRawValue
        self.isLate = isLate
        self.checkedInAt = checkedInAt
        self.frontImageData = frontImageData
        self.rearImageData = rearImageData
        self.expiresAt = expiresAt
    }
}
