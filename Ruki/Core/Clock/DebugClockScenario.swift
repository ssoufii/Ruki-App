import Foundation

/// T3 DEBUG tools: named clock-jump targets a tester can pick instead of
/// waiting for the real adhan. Pure — computes each target from
/// `FixedPrayerTimeProvider`'s known times for `referenceNow`'s calendar
/// day, independent of the user's own madhab/window settings, so every
/// scenario means the same wall-clock moment regardless of what's
/// configured. Only ever driven from a DEBUG build's Settings screen, but
/// nothing about the type itself needs to be `#if DEBUG` — it's inert,
/// harmless pure computation either way (same reasoning as `OffsetClock`).
enum DebugClockScenario: String, CaseIterable, Sendable, Identifiable {
    case fajrOpen
    case dhuhrJustBegan
    case asrLatePhase
    case maghribLatePhase
    case ishaJustBegan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fajrOpen: String(localized: "Fajr open")
        case .dhuhrJustBegan: String(localized: "Dhuhr just began")
        case .asrLatePhase: String(localized: "Asr, late phase")
        case .maghribLatePhase: String(localized: "Maghrib, late phase")
        case .ishaJustBegan: String(localized: "Isha just began")
        }
    }

    /// The instant this scenario represents. Always computed against the
    /// standard madhab: Asr's two timings don't change which scenario this
    /// is, only shift it by the same few minutes either way.
    ///
    /// Always *tomorrow's* prayer, whatever the time of day now. All five
    /// scenarios therefore share one calendar day, so check-ins made across
    /// several jumps stay on the same Today screen, and two accounts jumping to
    /// the same scenario land on the same slot. Tomorrow also keeps every prayer
    /// after an account's start date, so each one can actually be checked in for.
    func date(referenceNow: Date) -> Date {
        date(onDayOf: TorontoCalendar.startOfDay(byAdding: 1, to: referenceNow))
    }

    private func date(onDayOf day: Date) -> Date {
        let windows = FixedPrayerTimeProvider().prayerWindows(for: day, madhab: .standard)
        // Force unwrap is safe: `FixedPrayerTimeProvider` always returns
        // exactly one window per `Prayer` case.
        func window(for prayer: Prayer) -> PrayerWindow {
            windows.first { $0.prayer == prayer }!
        }

        switch self {
        case .fajrOpen:
            return window(for: .fajr).start.addingTimeInterval(5 * 60)
        case .dhuhrJustBegan:
            return window(for: .dhuhr).start.addingTimeInterval(60)
        case .asrLatePhase:
            let asr = window(for: .asr)
            return asr.checkInWindowEnd.addingTimeInterval(5 * 60)
        case .maghribLatePhase:
            // Maghrib's window is short (PRD SS9.2) -- this is the scenario
            // most worth being able to jump straight to.
            let maghrib = window(for: .maghrib)
            return maghrib.checkInWindowEnd.addingTimeInterval(5 * 60)
        case .ishaJustBegan:
            return window(for: .isha).start.addingTimeInterval(60)
        }
    }
}
