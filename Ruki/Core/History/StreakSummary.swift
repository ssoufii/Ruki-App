/// The three numbers the profile shows, and nothing more. Visible only to the
/// user — there is no sharing path and there must never be one (D24, RDP-1).
struct StreakSummary: Sendable, Equatable {
    /// Consecutive prayers checked in since the last miss. Counted in prayers, not days (D25).
    let current: Int
    /// Every prayer ever counted. Never resets, so a reset erases one number of three.
    let lifetime: Int
    /// On-time ÷ settled prayers over the last 30 days; `nil` until there's something to divide.
    let thirtyDayOnTimeRate: Double?
    /// The most recent settled prayer was a miss. Drives the forward-looking reset copy.
    let justReset: Bool

    static let empty = StreakSummary(current: 0, lifetime: 0, thirtyDayOnTimeRate: nil, justReset: false)
}
