import Foundation

/// Value-type view of a pause (RDP-3). `endsAt == nil` means "until I turn it
/// back on". Exists only on-device; nothing friend-facing ever carries it (RUKI-035).
struct PauseSnapshot: Sendable, Equatable {
    let startedAt: Date
    let endsAt: Date?

    nonisolated func isActive(at now: Date) -> Bool {
        startedAt <= now && now < (endsAt ?? .distantFuture)
    }

    /// True if the pause touches any part of the window. Overlap, not "started
    /// inside", so pausing mid-Asr protects that Asr: freezing must never
    /// convert a prayer the user was in the middle of into a miss.
    nonisolated func overlaps(_ window: PrayerWindow) -> Bool {
        startedAt < window.end && (endsAt ?? .distantFuture) > window.start
    }
}
