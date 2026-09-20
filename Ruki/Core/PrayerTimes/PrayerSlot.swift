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
}
