import Foundation

/// The history calendar's data: one row per prayer, one column per day
/// (PRD §7.7 Calendar). Pure value type — `CalendarGridBuilder` produces it,
/// nothing about it depends on `Date()` or the system clock directly.
struct CalendarGrid: Sendable, Equatable {
    struct Cell: Sendable, Equatable, Identifiable {
        let slot: PrayerSlot
        let outcome: SlotOutcome
        var id: String { slot.id }
    }

    struct Day: Sendable, Equatable, Identifiable {
        let dayKey: String
        let date: Date
        /// Keyed by prayer rather than a fixed-size array: a day can be
        /// missing a cell (e.g. `notTracked` slots aren't even generated
        /// before... no — every day in range always has all five; this stays
        /// a dictionary because that's the natural shape for "look up Fajr's
        /// cell for this day" and callers should never assume order from it.
        let cells: [Prayer: Cell]
        var id: String { dayKey }
    }

    /// Fixed display order everywhere in the app that lists all five prayers.
    static let prayerOrder: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    /// Ascending by date — oldest column first, matching how the grid reads left-to-right.
    let days: [Day]
}

/// Per-prayer totals across a `CalendarGrid`, for the "your Fajr is the
/// problem" breakdown (PRD §7.7). Counts, not a rate: a rate on a handful of
/// days is noisy in a way a plain count isn't.
struct PrayerBreakdown: Sendable, Equatable, Identifiable {
    let prayer: Prayer
    let onTimeCount: Int
    let lateCount: Int
    let markedPrayedCount: Int
    let missedCount: Int
    let pausedCount: Int
    var id: Prayer { prayer }
}

/// Builds a `CalendarGrid` and its per-prayer breakdown from resolved slots. Pure.
struct CalendarGridBuilder: Sendable {
    nonisolated func grid(
        from startDate: Date,
        through endDate: Date,
        timeline: PrayerTimeline,
        resolver: SlotResolver,
        now: Date
    ) -> CalendarGrid {
        var cellsByDay: [String: [Prayer: CalendarGrid.Cell]] = [:]
        var dateByDay: [String: Date] = [:]
        var dayOrder: [String] = []

        for slot in timeline.slots(from: startDate, through: endDate) {
            let cell = CalendarGrid.Cell(slot: slot, outcome: resolver.outcome(for: slot, now: now))
            if cellsByDay[slot.dayKey] == nil {
                cellsByDay[slot.dayKey] = [:]
                dateByDay[slot.dayKey] = TorontoCalendar.startOfDay(for: slot.window.start)
                dayOrder.append(slot.dayKey)
            }
            cellsByDay[slot.dayKey]?[slot.prayer] = cell
        }

        let days = dayOrder.map { key in
            CalendarGrid.Day(dayKey: key, date: dateByDay[key] ?? startDate, cells: cellsByDay[key] ?? [:])
        }
        return CalendarGrid(days: days)
    }

    nonisolated func breakdown(for grid: CalendarGrid) -> [PrayerBreakdown] {
        CalendarGrid.prayerOrder.map { prayer in
            var onTime = 0, late = 0, markedPrayed = 0, missed = 0, paused = 0
            for day in grid.days {
                guard let cell = day.cells[prayer] else { continue }
                switch cell.outcome {
                case .onTime: onTime += 1
                case .late: late += 1
                case .markedPrayed: markedPrayed += 1
                case .missed: missed += 1
                case .paused: paused += 1
                case .pending, .notTracked: break
                }
            }
            return PrayerBreakdown(
                prayer: prayer, onTimeCount: onTime, lateCount: late,
                markedPrayedCount: markedPrayed, missedCount: missed, pausedCount: paused
            )
        }
    }
}
