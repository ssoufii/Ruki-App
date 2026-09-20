import Foundation

/// Decides the `SlotOutcome` of a slot from the user's records. Pure.
struct SlotResolver: Sendable {
    private let checkIns: [String: CheckInSnapshot]
    private let marks: [String: MarkSnapshot]
    private let pauses: [PauseSnapshot]
    private let trackingStart: Date

    /// - Parameter trackingStart: when the user began using Ruki. Prayers whose
    ///   window began earlier aren't part of their history — installing at 4 p.m.
    ///   must not open with a row of misses.
    init(checkIns: [CheckInSnapshot], marks: [MarkSnapshot], pauses: [PauseSnapshot], trackingStart: Date) {
        self.checkIns = Dictionary(checkIns.map { ($0.slotID, $0) }, uniquingKeysWith: { first, _ in first })
        self.marks = Dictionary(marks.map { ($0.slotID, $0) }, uniquingKeysWith: { _, latest in latest })
        self.pauses = pauses
        self.trackingStart = trackingStart
    }

    nonisolated func outcome(for slot: PrayerSlot, now: Date) -> SlotOutcome {
        if let checkIn = checkIns[slot.id] {
            return checkIn.isLate ? .late : .onTime
        }
        if let mark = marks[slot.id] {
            return mark.kind == .prayed ? .markedPrayed : .missed
        }
        if slot.window.start < trackingStart { return .notTracked }
        if pauses.contains(where: { $0.overlaps(slot.window) }) {
            // Once the window has closed, an overlap is permanent (D38): the
            // whole point is that a pause ending mid-window must not let it
            // lapse into `.missed`. But while the window is still open, only
            // a *currently active* pause should read as `.paused` -- resuming
            // (RDP-3) must free up the window it was invoked during, not lock
            // it into `.paused` forever just because some earlier pause once
            // touched it.
            if now >= slot.window.end || pauses.contains(where: { $0.isActive(at: now) }) {
                return .paused
            }
        }
        return now < slot.window.end ? .pending : .missed
    }
}
