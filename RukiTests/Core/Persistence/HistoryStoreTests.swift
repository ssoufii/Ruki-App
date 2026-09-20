import Foundation
import SwiftData
import Testing
@testable import Ruki

@Suite("HistoryStore")
@MainActor
struct HistoryStoreTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!

    private func makeStore() throws -> HistoryStore {
        HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
    }

    private func makeSlot(prayer: Prayer = .fajr, start: Date) -> PrayerSlot {
        let window = PrayerWindow(
            prayer: prayer,
            madhab: .standard,
            start: start,
            checkInWindowEnd: start.addingTimeInterval(30 * 60),
            end: start.addingTimeInterval(60 * 60)
        )
        return PrayerSlot(window: window)
    }

    @Test("Recording a check-in makes it show up as a snapshot")
    func recordsCheckIn() throws {
        let store = try makeStore()
        let slot = makeSlot(start: referenceDate)

        try store.recordCheckIn(
            for: slot,
            isLate: false,
            checkedInAt: referenceDate,
            frontImageData: Data([0x1]),
            rearImageData: Data([0x2]),
            expiresAt: referenceDate.addingTimeInterval(3600)
        )

        let snapshots = try store.checkInSnapshots()
        #expect(snapshots == [CheckInSnapshot(slotID: slot.id, isLate: false)])
    }

    @Test("A second check-in for the same slot overwrites, never duplicates (RUKI-033)")
    func oneCheckInPerSlot() throws {
        let store = try makeStore()
        let slot = makeSlot(start: referenceDate)

        try store.recordCheckIn(
            for: slot, isLate: false, checkedInAt: referenceDate,
            frontImageData: nil, rearImageData: Data([0x1]), expiresAt: referenceDate.addingTimeInterval(3600)
        )
        try store.recordCheckIn(
            for: slot, isLate: true, checkedInAt: referenceDate.addingTimeInterval(600),
            frontImageData: nil, rearImageData: Data([0x2]), expiresAt: referenceDate.addingTimeInterval(3600)
        )

        let snapshots = try store.checkInSnapshots()
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.isLate == true)
    }

    @Test("recordCheckIn persists the caption when one is given, and defaults to nil (RUKI-023)")
    func recordCheckInPersistsCaption() throws {
        let container = try RukiModelContainer.make(inMemory: true)
        let store = HistoryStore(modelContainer: container)
        let withCaption = makeSlot(prayer: .fajr, start: referenceDate)
        let withoutCaption = makeSlot(prayer: .dhuhr, start: referenceDate.addingTimeInterval(3600))

        try store.recordCheckIn(
            for: withCaption, isLate: false, checkedInAt: referenceDate,
            frontImageData: nil, rearImageData: nil, expiresAt: referenceDate.addingTimeInterval(3600),
            caption: "Alhamdulillah"
        )
        try store.recordCheckIn(
            for: withoutCaption, isLate: false, checkedInAt: referenceDate,
            frontImageData: nil, rearImageData: nil, expiresAt: referenceDate.addingTimeInterval(3600)
        )

        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<CheckInRecord>())
        #expect(records.first { $0.slotID == withCaption.id }?.caption == "Alhamdulillah")
        #expect(records.first { $0.slotID == withoutCaption.id }?.caption == nil)
    }

    @Test("recordCheckIn persists retakeCount, and defaults to 0 (RUKI-027)")
    func recordCheckInPersistsRetakeCount() throws {
        let container = try RukiModelContainer.make(inMemory: true)
        let store = HistoryStore(modelContainer: container)
        let retaken = makeSlot(prayer: .fajr, start: referenceDate)
        let notRetaken = makeSlot(prayer: .dhuhr, start: referenceDate.addingTimeInterval(3600))

        try store.recordCheckIn(
            for: retaken, isLate: false, checkedInAt: referenceDate,
            frontImageData: nil, rearImageData: nil, expiresAt: referenceDate.addingTimeInterval(3600),
            retakeCount: 1
        )
        try store.recordCheckIn(
            for: notRetaken, isLate: false, checkedInAt: referenceDate,
            frontImageData: nil, rearImageData: nil, expiresAt: referenceDate.addingTimeInterval(3600)
        )

        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<CheckInRecord>())
        #expect(records.first { $0.slotID == retaken.id }?.retakeCount == 1)
        #expect(records.first { $0.slotID == notRetaken.id }?.retakeCount == 0)
    }

    @Test("Recording a mark makes it show up as a snapshot, and a second mark replaces the first")
    func recordsMark() throws {
        let store = try makeStore()
        let slot = makeSlot(start: referenceDate)

        try store.recordMark(for: slot, kind: .missed, markedAt: referenceDate)
        try store.recordMark(for: slot, kind: .prayed, markedAt: referenceDate.addingTimeInterval(60))

        let snapshots = try store.markSnapshots()
        #expect(snapshots == [MarkSnapshot(slotID: slot.id, kind: .prayed)])
    }

    @Test("Recording a pause makes it show up as a snapshot; multiple pauses accumulate")
    func recordsPauses() throws {
        let store = try makeStore()

        try store.recordPause(startedAt: referenceDate, endsAt: referenceDate.addingTimeInterval(3600))
        try store.recordPause(startedAt: referenceDate.addingTimeInterval(7200), endsAt: nil)

        let snapshots = try store.pauseSnapshots()
        #expect(snapshots.count == 2)
        #expect(snapshots.contains { $0.endsAt == nil })
    }

    @Test("Expired photos are purged; the check-in record survives (D26, D37)")
    func purgesExpiredPhotosOnly() throws {
        let container = try RukiModelContainer.make(inMemory: true)
        let store = HistoryStore(modelContainer: container)
        let expiredSlot = makeSlot(prayer: .fajr, start: referenceDate)
        let liveSlot = makeSlot(prayer: .dhuhr, start: referenceDate.addingTimeInterval(3600))

        try store.recordCheckIn(
            for: expiredSlot, isLate: false, checkedInAt: referenceDate,
            frontImageData: Data([0x1]), rearImageData: Data([0x2]),
            expiresAt: referenceDate.addingTimeInterval(1800)
        )
        try store.recordCheckIn(
            for: liveSlot, isLate: false, checkedInAt: referenceDate.addingTimeInterval(3600),
            frontImageData: Data([0x3]), rearImageData: Data([0x4]),
            expiresAt: referenceDate.addingTimeInterval(7200)
        )

        try store.purgeExpiredPhotos(now: referenceDate.addingTimeInterval(1800))

        // The fact of both check-ins survives regardless of purge.
        let snapshots = try store.checkInSnapshots()
        #expect(Set(snapshots.map(\.slotID)) == [expiredSlot.id, liveSlot.id])

        // Inspect the raw records: the expired one lost its photos, the live one kept them.
        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<CheckInRecord>())
        let expired = try #require(records.first { $0.slotID == expiredSlot.id })
        let live = try #require(records.first { $0.slotID == liveSlot.id })
        #expect(expired.frontImageData == nil && expired.rearImageData == nil)
        #expect(live.frontImageData == Data([0x3]) && live.rearImageData == Data([0x4]))
    }

    @Test("exportSnapshot includes every record's fields but never a photo (RUKI-037, D37)")
    func exportSnapshotExcludesPhotos() throws {
        let store = try makeStore()
        let checkInSlot = makeSlot(prayer: .fajr, start: referenceDate)
        let markSlot = makeSlot(prayer: .dhuhr, start: referenceDate.addingTimeInterval(3600))
        try store.recordCheckIn(
            for: checkInSlot, isLate: true, checkedInAt: referenceDate,
            frontImageData: Data([0x1]), rearImageData: Data([0x2]),
            expiresAt: referenceDate.addingTimeInterval(7200), caption: "Alhamdulillah"
        )
        try store.recordMark(for: markSlot, kind: .prayed, markedAt: referenceDate)
        try store.recordPause(startedAt: referenceDate, endsAt: nil)

        let export = try store.exportSnapshot(exportedAt: referenceDate.addingTimeInterval(10_800))

        #expect(export.exportedAt == referenceDate.addingTimeInterval(10_800))
        #expect(export.checkIns == [
            HistoryExport.CheckIn(
                slotID: checkInSlot.id, prayer: Prayer.fajr.rawValue, dayKey: checkInSlot.dayKey,
                isLate: true, checkedInAt: referenceDate, caption: "Alhamdulillah"
            ),
        ])
        #expect(export.marks == [HistoryExport.Mark(slotID: markSlot.id, kind: MarkSnapshot.Kind.prayed.rawValue, markedAt: referenceDate)])
        #expect(export.pauses == [HistoryExport.Pause(startedAt: referenceDate, endsAt: nil)])
    }

    @Test("deleteAll wipes every check-in, mark, and pause (RUKI-037)")
    func deleteAllWipesEverything() throws {
        let store = try makeStore()
        let slot = makeSlot(start: referenceDate)
        try store.recordCheckIn(
            for: slot, isLate: false, checkedInAt: referenceDate,
            frontImageData: nil, rearImageData: nil, expiresAt: referenceDate.addingTimeInterval(3600)
        )
        try store.recordMark(for: slot, kind: .prayed, markedAt: referenceDate)
        try store.recordPause(startedAt: referenceDate, endsAt: nil)

        try store.deleteAll()

        #expect(try store.checkInSnapshots().isEmpty)
        #expect(try store.markSnapshots().isEmpty)
        #expect(try store.pauseSnapshots().isEmpty)
    }

    @Test("SwiftDataPersistence produces a usable in-memory container")
    func swiftDataPersistenceInMemory() throws {
        let persistence = try SwiftDataPersistence(inMemory: true)
        let store = HistoryStore(modelContainer: persistence.modelContainer)
        let slot = makeSlot(start: referenceDate)

        try store.recordCheckIn(
            for: slot, isLate: false, checkedInAt: referenceDate,
            frontImageData: nil, rearImageData: nil, expiresAt: referenceDate.addingTimeInterval(3600)
        )

        #expect(try store.checkInSnapshots().count == 1)
    }
}
