/// Where "now" sits relative to one prayer's check-in window.
enum CheckInPhase: Sendable, Equatable {
    /// The adhan hasn't come yet. Check-in isn't available.
    case upcoming
    /// Inside the on-time window.
    case onTime
    /// Past the on-time window but the prayer window is still open. Still
    /// accepted, still counts (PRD §7.4) — flagged Late, never a failure.
    case late
    /// The prayer window has closed. Only a private mark is possible now.
    case closed

    var acceptsCheckIn: Bool { self == .onTime || self == .late }
}
