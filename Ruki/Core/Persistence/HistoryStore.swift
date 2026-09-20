import Foundation
import SwiftData

/// The single point of truth for the user's on-device history (D26). Bridges
/// SwiftData's reference model types to the value-type snapshots the pure
/// history logic (`SlotResolver`, `StreakCalculator`) reasons about.
///
/// `@MainActor` because `ModelContext` isn't `Sendable` — every call into
/// this store happens from the main actor, same as the UI that drives it.
@MainActor
final class HistoryStore {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
    }

    // MARK: Recording

    /// Records a check-in for `slot`. One check-in per slot (RUKI-033): a
    /// second call for the same slot overwrites the existing record rather
    /// than creating a duplicate.
    func recordCheckIn(
        for slot: PrayerSlot,
        isLate: Bool,
        checkedInAt: Date,
        frontImageData: Data?,
        rearImageData: Data?,
        expiresAt: Date,
        caption: String? = nil
    ) throws {
        if let existing = try fetchCheckIn(slotID: slot.id) {
            existing.isLate = isLate
            existing.checkedInAt = checkedInAt
            existing.frontImageData = frontImageData
            existing.rearImageData = rearImageData
            existing.expiresAt = expiresAt
            existing.caption = caption
        } else {
            modelContext.insert(
                CheckInRecord(
                    slotID: slot.id,
                    dayKey: slot.dayKey,
                    prayerRawValue: slot.prayer.rawValue,
                    isLate: isLate,
                    checkedInAt: checkedInAt,
                    frontImageData: frontImageData,
                    rearImageData: rearImageData,
                    expiresAt: expiresAt,
                    caption: caption
                )
            )
        }
        try modelContext.save()
    }

    /// Records a private mark on a closed window. One mark per slot: a
    /// second call replaces the first rather than creating a duplicate.
    func recordMark(for slot: PrayerSlot, kind: MarkSnapshot.Kind, markedAt: Date) throws {
        if let existing = try fetchMark(slotID: slot.id) {
            existing.kindRawValue = kind.rawValue
            existing.markedAt = markedAt
        } else {
            modelContext.insert(PrayerMark(slotID: slot.id, kindRawValue: kind.rawValue, markedAt: markedAt))
        }
        try modelContext.save()
    }

    func recordPause(startedAt: Date, endsAt: Date?) throws {
        modelContext.insert(PauseRecord(startedAt: startedAt, endsAt: endsAt))
        try modelContext.save()
    }

    // MARK: Purge

    /// Drops photo data for every check-in whose window has expired (D37).
    /// The record itself — the fact of having prayed — is untouched (D26).
    func purgeExpiredPhotos(now: Date) throws {
        let expired = FetchDescriptor<CheckInRecord>(
            predicate: #Predicate { record in
                record.expiresAt <= now && (record.frontImageData != nil || record.rearImageData != nil)
            }
        )
        for record in try modelContext.fetch(expired) {
            record.frontImageData = nil
            record.rearImageData = nil
        }
        try modelContext.save()
    }

    // MARK: Snapshots

    /// Value-type view of every check-in, for `SlotResolver`.
    func checkInSnapshots() throws -> [CheckInSnapshot] {
        try modelContext.fetch(FetchDescriptor<CheckInRecord>())
            .map { CheckInSnapshot(slotID: $0.slotID, isLate: $0.isLate) }
    }

    /// Value-type view of every mark, for `SlotResolver`.
    func markSnapshots() throws -> [MarkSnapshot] {
        try modelContext.fetch(FetchDescriptor<PrayerMark>())
            .compactMap { record in
                guard let kind = MarkSnapshot.Kind(rawValue: record.kindRawValue) else { return nil }
                return MarkSnapshot(slotID: record.slotID, kind: kind)
            }
    }

    /// Value-type view of every pause, for `SlotResolver`.
    func pauseSnapshots() throws -> [PauseSnapshot] {
        try modelContext.fetch(FetchDescriptor<PauseRecord>())
            .map { PauseSnapshot(startedAt: $0.startedAt, endsAt: $0.endsAt) }
    }

    // MARK: Private

    private func fetchCheckIn(slotID: String) throws -> CheckInRecord? {
        var descriptor = FetchDescriptor<CheckInRecord>(predicate: #Predicate { $0.slotID == slotID })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchMark(slotID: String) throws -> PrayerMark? {
        var descriptor = FetchDescriptor<PrayerMark>(predicate: #Predicate { $0.slotID == slotID })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
