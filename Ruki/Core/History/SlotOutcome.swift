/// What became of one prayer slot, from the user's own point of view.
/// Everything here is private, on-device state (RDP-2): `.missed` and
/// `.paused` are never serialised into anything a friend can read.
enum SlotOutcome: Sendable, Equatable {
    case onTime
    case late
    /// The user privately marked a closed window as prayed. Counts (PRD §7.7):
    /// the whole app is self-attestation, and refusing the user's own record
    /// would be the app calling them a liar.
    case markedPrayed
    case missed
    /// Covered by a pause. Neither counted nor missed — the streak is frozen.
    case paused
    /// The window is still open and nothing has been recorded yet.
    case pending
    /// Began before the user started using Ruki; not part of their history.
    case notTracked

    /// Whether this slot extends the streak.
    var counts: Bool { self == .onTime || self == .late || self == .markedPrayed }

    /// Whether this slot is settled and belongs in a rate (paused/pending/untracked don't).
    var isResolved: Bool { counts || self == .missed }
}
