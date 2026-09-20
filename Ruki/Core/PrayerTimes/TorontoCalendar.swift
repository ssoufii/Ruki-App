import Foundation

/// The one calendar the app reasons about days in. The MVP is Toronto-only
/// (D19), so "today" means Toronto's today regardless of the device's zone —
/// a phone set to another zone must not shift a check-in onto a different day.
enum TorontoCalendar {
    // Force unwrap is safe: "America/Toronto" is a valid, stable IANA identifier.
    nonisolated static let timeZone = TimeZone(identifier: "America/Toronto")!

    nonisolated static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Stable `yyyy-MM-dd` key for the Toronto calendar day containing `date`.
    nonisolated static func dayKey(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    nonisolated static func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Start of the day `days` after the day containing `date`. Uses the
    /// calendar rather than adding 86,400s so DST days (23h / 25h) stay correct.
    nonisolated static func startOfDay(byAdding days: Int, to date: Date) -> Date {
        // Force unwrap is safe: adding whole days to a valid Gregorian date succeeds.
        calendar.date(byAdding: .day, value: days, to: startOfDay(for: date))!
    }
}
