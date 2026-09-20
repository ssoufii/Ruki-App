import Foundation

/// Answers "which prayer is open, what phase is it in, and what's next?" on
/// top of a `PrayerTimeProviding`. Pure — every method takes `now` explicitly
/// so nothing here can reach for the system clock.
struct PrayerTimeline: Sendable {
    let provider: any PrayerTimeProviding
    let madhab: Madhab

    // MARK: Slots

    nonisolated func slots(onDayOf date: Date) -> [PrayerSlot] {
        provider.prayerWindows(for: date, madhab: madhab).map(PrayerSlot.init)
    }

    /// Every slot whose window *starts* between the start of `startDate`'s day
    /// and `endDate`, in chronological order.
    nonisolated func slots(from startDate: Date, through endDate: Date) -> [PrayerSlot] {
        var result: [PrayerSlot] = []
        var day = TorontoCalendar.startOfDay(for: startDate)
        while day <= endDate {
            result += slots(onDayOf: day).filter { $0.window.start <= endDate }
            day = TorontoCalendar.startOfDay(byAdding: 1, to: day)
        }
        return result
    }

    // MARK: Now

    /// The prayer window containing `now`, if any. Looks at yesterday too,
    /// because Isha runs until the next Fajr (D30). Between sunrise and Dhuhr
    /// no window is open and this is `nil`.
    nonisolated func activeSlot(at now: Date) -> PrayerSlot? {
        let yesterday = TorontoCalendar.startOfDay(byAdding: -1, to: now)
        return (slots(onDayOf: yesterday) + slots(onDayOf: now))
            .first { $0.window.start <= now && now < $0.window.end }
    }

    nonisolated func nextSlot(after now: Date) -> PrayerSlot? {
        let tomorrow = TorontoCalendar.startOfDay(byAdding: 1, to: now)
        return (slots(onDayOf: now) + slots(onDayOf: tomorrow))
            .first { $0.window.start > now }
    }

    /// The next Fajr adhan strictly after `now`, for forward-looking copy.
    nonisolated func nextFajr(after now: Date) -> PrayerSlot? {
        let tomorrow = TorontoCalendar.startOfDay(byAdding: 1, to: now)
        return (slots(onDayOf: now) + slots(onDayOf: tomorrow))
            .first { $0.prayer == .fajr && $0.window.start > now }
    }

    // MARK: Phase

    /// The on-time cutoff, honouring the user's chosen window length (RUKI-036).
    ///
    /// The setting can only *shorten* the default: taking the minimum with
    /// `checkInWindowEnd` keeps Maghrib at 20 minutes even if 30 is chosen, and
    /// means Fajr — whose default runs adhan → sunrise (D17) — is never
    /// shortened by a setting meant for the 30-minute prayers.
    nonisolated func onTimeEnd(of window: PrayerWindow, userWindowMinutes: Int) -> Date {
        guard window.prayer != .fajr else { return window.checkInWindowEnd }
        return min(window.checkInWindowEnd, window.start.addingTimeInterval(TimeInterval(userWindowMinutes * 60)))
    }

    nonisolated func phase(of slot: PrayerSlot, at now: Date, userWindowMinutes: Int) -> CheckInPhase {
        let window = slot.window
        if now < window.start { return .upcoming }
        if now < onTimeEnd(of: window, userWindowMinutes: userWindowMinutes) { return .onTime }
        if now < window.end { return .late }
        return .closed
    }
}
