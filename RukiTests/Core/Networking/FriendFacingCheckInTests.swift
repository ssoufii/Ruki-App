import Foundation
import Testing
@testable import Ruki

@Suite("FriendFacingCheckIn")
struct FriendFacingCheckInTests {
    private static let forbiddenKeys: Set<String> = [
        "pausedUntil", "paused", "isPaused", "pauseState", "pauseRecord",
        "missed", "isMissed", "missedRecord", "note",
        "location", "latitude", "longitude", "coordinate",
    ]

    private let sample = FriendFacingCheckIn(
        id: "check-in-1",
        userID: "user-1",
        prayer: .fajr,
        prayedAt: Date(timeIntervalSince1970: 1_800_000_000),
        promptedAt: Date(timeIntervalSince1970: 1_799_999_000),
        isLate: false,
        retakeCount: 0,
        caption: "alhamdulillah",
        frontPhotoKey: "front.jpg",
        rearPhotoKey: "rear.jpg",
        expiresAt: Date(timeIntervalSince1970: 1_800_003_600)
    )

    @Test("The encoded JSON contains none of the forbidden keys (RUKI-035, RDP-2/RDP-3, D8)")
    func encodedPayloadHasNoForbiddenKeys() throws {
        let data = try JSONEncoder().encode(sample)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let keys = Set(object.keys)
        #expect(keys.isDisjoint(with: Self.forbiddenKeys))
    }

    @Test("Reflecting over the type's stored properties finds none of the forbidden fields")
    func mirrorHasNoForbiddenFields() {
        let labels = Set(Mirror(reflecting: sample).children.compactMap(\.label))
        #expect(labels.isDisjoint(with: Self.forbiddenKeys))
    }

    @Test("Encoding then decoding round-trips without loss")
    func roundTrips() throws {
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(FriendFacingCheckIn.self, from: data)
        #expect(decoded == sample)
    }
}
