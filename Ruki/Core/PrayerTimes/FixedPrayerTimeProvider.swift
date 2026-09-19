import Foundation

/// MVP prayer-time source: one day's real Toronto times, captured once and
/// reused unchanged for every date requested. No network call, no daily
/// recomputation, no dependency on AlAdhan or OQ-8.
///
/// **This is a deliberate, temporary simplification — MEMORY.md decision D27.**
/// Toronto Fajr alone swings roughly 3:30 a.m. (June) to 6:00 a.m. (December),
/// so these frozen times drift wrong within days in either direction from the
/// capture date below. This type must never reach a user beyond internal
/// dogfooding. GitHub Epic 13 replaces it with the real AlAdhan-backed engine,
/// swapped in behind this same `PrayerTimeProviding` conformance, before
/// M2/TestFlight (RUKI-065).
///
/// Capture reference: Toronto, ON (43.6532° N, 79.3832° W), 2026-09-19,
/// approximate ISNA-convention times. Not verified against a specific masjid
/// timetable — that alignment is OQ-8, tracked in Epic 13 (RUKI-059).
struct FixedPrayerTimeProvider: PrayerTimeProviding {
    // nonisolated: this whole type is pure, stateless computation that must be
    // callable from background contexts (BGAppRefreshTask, Epic 04) — the
    // project's default-MainActor isolation would otherwise pin it there.

    // Force unwrap is safe: "America/Toronto" is a valid, stable IANA identifier.
    private nonisolated static let torontoTimeZone = TimeZone(identifier: "America/Toronto")!

    private nonisolated static let fajr = TimeOfDay(hour: 5, minute: 20)
    private nonisolated static let sunrise = TimeOfDay(hour: 6, minute: 52)
    private nonisolated static let dhuhr = TimeOfDay(hour: 13, minute: 5)
    private nonisolated static let asrStandard = TimeOfDay(hour: 16, minute: 35)
    private nonisolated static let asrHanafi = TimeOfDay(hour: 17, minute: 25)
    private nonisolated static let maghrib = TimeOfDay(hour: 19, minute: 15)
    private nonisolated static let isha = TimeOfDay(hour: 20, minute: 40)

    nonisolated func prayerWindows(for date: Date, madhab: Madhab) -> [PrayerWindow] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.torontoTimeZone

        let asr = madhab == .hanafi ? Self.asrHanafi : Self.asrStandard

        let fajrStart = Self.fajr.date(onDayOf: date, calendar: calendar)
        let sunriseTime = Self.sunrise.date(onDayOf: date, calendar: calendar)
        let dhuhrStart = Self.dhuhr.date(onDayOf: date, calendar: calendar)
        let asrStart = asr.date(onDayOf: date, calendar: calendar)
        let maghribStart = Self.maghrib.date(onDayOf: date, calendar: calendar)
        let ishaStart = Self.isha.date(onDayOf: date, calendar: calendar)

        // Force unwrap is safe: adding one day to any valid Gregorian date succeeds.
        let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
        // D30: Isha stays open until the next Fajr adhan so a valid late-night
        // prayer is never refused. Fajr's time is the same every day here.
        let nextFajrStart = Self.fajr.date(onDayOf: nextDay, calendar: calendar)

        return [
            PrayerWindow(
                prayer: .fajr, madhab: madhab,
                start: fajrStart,
                // Option A (OQ-9, resolved): window runs adhan -> sunrise, no separate Late phase.
                checkInWindowEnd: sunriseTime,
                end: sunriseTime
            ),
            PrayerWindow(
                prayer: .dhuhr, madhab: madhab,
                start: dhuhrStart,
                checkInWindowEnd: dhuhrStart.addingTimeInterval(30 * 60),
                end: asrStart
            ),
            PrayerWindow(
                prayer: .asr, madhab: madhab,
                start: asrStart,
                checkInWindowEnd: asrStart.addingTimeInterval(30 * 60),
                end: maghribStart
            ),
            PrayerWindow(
                prayer: .maghrib, madhab: madhab,
                start: maghribStart,
                // Shortest window in the day (PRD §9.2) — 20 min, not 30.
                checkInWindowEnd: maghribStart.addingTimeInterval(20 * 60),
                end: ishaStart
            ),
            PrayerWindow(
                prayer: .isha, madhab: madhab,
                start: ishaStart,
                checkInWindowEnd: ishaStart.addingTimeInterval(30 * 60),
                end: nextFajrStart
            ),
        ]
    }
}

/// A wall-clock hour/minute, resolved onto a specific calendar day.
///
/// Deliberately not DST-aware beyond what `Calendar` does automatically:
/// the fixed provider's times are placeholders (see type doc above), so the
/// spring-forward/fall-back edge cases that matter for the real engine are
/// exercised there (Epic 13, RUKI-064), not here.
private struct TimeOfDay {
    let hour: Int
    let minute: Int

    nonisolated func date(onDayOf referenceDate: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        // Force unwrap is safe: year/month/day come from a real Date via the
        // same calendar, and hour/minute/second are always in-range here.
        return calendar.date(from: components)!
    }
}
