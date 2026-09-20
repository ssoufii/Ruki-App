import Foundation

/// RUKI-034: the five pause lengths PRD §7.8 offers. No reason field —
/// picking one is the whole flow, and every case is a fixed length so
/// there's nothing else to configure.
enum PauseDuration: CaseIterable, Sendable {
    case today
    case threeDays
    case sevenDays
    case tenDays
    case untilResumed

    var label: String {
        switch self {
        case .today: String(localized: "Today")
        case .threeDays: String(localized: "3 days")
        case .sevenDays: String(localized: "7 days")
        case .tenDays: String(localized: "10 days")
        case .untilResumed: String(localized: "Until I turn it back on")
        }
    }

    /// `nil` for `.untilResumed` — `PauseSnapshot`'s own convention for
    /// open-ended (D38). Every other case is a fixed offset from `now`;
    /// `.today` ends at the start of tomorrow (Toronto) so it never leaks
    /// past the calendar day regardless of what time it's tapped.
    nonisolated func endsAt(from now: Date) -> Date? {
        switch self {
        case .today: TorontoCalendar.startOfDay(byAdding: 1, to: now)
        case .threeDays: now.addingTimeInterval(3 * 24 * 60 * 60)
        case .sevenDays: now.addingTimeInterval(7 * 24 * 60 * 60)
        case .tenDays: now.addingTimeInterval(10 * 24 * 60 * 60)
        case .untilResumed: nil
        }
    }
}
