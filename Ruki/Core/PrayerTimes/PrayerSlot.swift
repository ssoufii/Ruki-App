import Foundation

/// One prayer on one Toronto calendar day — the unit the streak, calendar and
/// check-in records are all keyed on. `dayKey` is derived from the window's
/// *start*, so last night's Isha (which runs past midnight, D30) stays on the
/// day it began.
struct PrayerSlot: Sendable, Equatable, Identifiable {
    let window: PrayerWindow
    let dayKey: String

    var prayer: Prayer { window.prayer }
    var id: String { "\(dayKey).\(prayer.rawValue)" }

    init(window: PrayerWindow) {
        self.window = window
        self.dayKey = TorontoCalendar.dayKey(for: window.start)
    }

    /// The `Prayer` half of an `id` produced by this type — the only piece a
    /// tapped notification's request identifier carries (RUKI-014). `dayKey`
    /// is discarded rather than reconstructed into a full `PrayerSlot`: a
    /// stale notification firing after a day rollover shouldn't resurrect
    /// yesterday's slot, and every caller that has this only needs to know
    /// which prayer to show, not its exact window.
    static func prayer(fromID id: String) -> Prayer? {
        guard let lastDot = id.lastIndex(of: ".") else { return nil }
        return Prayer(rawValue: String(id[id.index(after: lastDot)...]))
    }
}
