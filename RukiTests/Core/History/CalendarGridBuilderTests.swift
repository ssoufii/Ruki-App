import Foundation
import Testing
@testable import Ruki

@Suite("CalendarGridBuilder")
struct CalendarGridBuilderTests {
    private let builder = CalendarGridBuilder()
    private let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard)
    // 2026-09-19T12:00:00Z: mid-morning Toronto, after Fajr's window has closed.
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!

    // Ends at the start of `referenceDate`'s own day, so both days in range are
    // fully in the past and every prayer on them has already opened — a range
    // that runs into today would give today's not-yet-open prayers no cell,
    // which is correct behaviour but not what these two tests are about.
    private var throughEndOfYesterday: Date { TorontoCalendar.startOfDay(for: referenceDate) }

    @Test("The grid has one column per completed day in range, each with all five prayers")
    func gridCoversEveryDayAndPrayer() {
        let start = TorontoCalendar.startOfDay(byAdding: -2, to: referenceDate)
        let resolver = SlotResolver(checkIns: [], marks: [], pauses: [], trackingStart: start)
        let grid = builder.grid(from: start, through: throughEndOfYesterday, timeline: timeline, resolver: resolver, now: referenceDate)

        #expect(grid.days.count == 2)
        for day in grid.days {
            #expect(Set(day.cells.keys) == Set(CalendarGrid.prayerOrder))
        }
    }

    @Test("Days are ordered oldest first")
    func daysAreAscending() {
        let start = TorontoCalendar.startOfDay(byAdding: -2, to: referenceDate)
        let resolver = SlotResolver(checkIns: [], marks: [], pauses: [], trackingStart: start)
        let grid = builder.grid(from: start, through: throughEndOfYesterday, timeline: timeline, resolver: resolver, now: referenceDate)

        #expect(grid.days == grid.days.sorted { $0.date < $1.date })
    }

    @Test("A recorded check-in shows up as onTime or late in its cell")
    func checkInReflectedInCell() throws {
        let today = TorontoCalendar.startOfDay(for: referenceDate)
        let fajr = timeline.slots(onDayOf: today).first { $0.prayer == .fajr }!
        let resolver = SlotResolver(
            checkIns: [CheckInSnapshot(slotID: fajr.id, isLate: false)],
            marks: [], pauses: [], trackingStart: today
        )
        let grid = builder.grid(from: today, through: referenceDate, timeline: timeline, resolver: resolver, now: referenceDate)

        let day = try #require(grid.days.first { $0.dayKey == fajr.dayKey })
        #expect(day.cells[.fajr]?.outcome == .onTime)
    }

    @Test("The breakdown totals on-time, late, marked-prayed, missed, and paused across the grid, per prayer")
    func breakdownTotalsPerPrayer() throws {
        let start = TorontoCalendar.startOfDay(byAdding: -1, to: referenceDate)
        let yesterday = start
        let fajrYesterday = timeline.slots(onDayOf: yesterday).first { $0.prayer == .fajr }!
        let fajrToday = timeline.slots(onDayOf: referenceDate).first { $0.prayer == .fajr }!
        let resolver = SlotResolver(
            checkIns: [CheckInSnapshot(slotID: fajrYesterday.id, isLate: true)],
            marks: [MarkSnapshot(slotID: fajrToday.id, kind: .prayed)],
            pauses: [],
            trackingStart: start
        )
        let grid = builder.grid(from: start, through: referenceDate, timeline: timeline, resolver: resolver, now: referenceDate)
        let breakdown = builder.breakdown(for: grid)

        let fajrBreakdown = try #require(breakdown.first { $0.prayer == .fajr })
        #expect(fajrBreakdown.lateCount == 1)
        #expect(fajrBreakdown.markedPrayedCount == 1)
        #expect(fajrBreakdown.onTimeCount == 0)

        // Yesterday's Dhuhr closed with no record (missed); today's Dhuhr
        // hasn't opened yet at this mid-morning reference time, so it isn't
        // in range at all.
        let dhuhrBreakdown = try #require(breakdown.first { $0.prayer == .dhuhr })
        #expect(dhuhrBreakdown.missedCount == 1)
    }

    @Test("A slot before tracking started does not count toward the breakdown")
    func notTrackedSlotsExcludedFromBreakdown() throws {
        // Onboarded partway through today, after Fajr's window already closed.
        let onboardedAt = ISO8601DateFormatter().date(from: "2026-09-19T13:00:00Z")!
        let resolver = SlotResolver(checkIns: [], marks: [], pauses: [], trackingStart: onboardedAt)
        let grid = builder.grid(
            from: TorontoCalendar.startOfDay(for: onboardedAt), through: onboardedAt,
            timeline: timeline, resolver: resolver, now: onboardedAt
        )
        let breakdown = builder.breakdown(for: grid)

        let fajrBreakdown = try #require(breakdown.first { $0.prayer == .fajr })
        #expect(fajrBreakdown.missedCount == 0)
        #expect(fajrBreakdown.onTimeCount == 0)
        #expect(fajrBreakdown.lateCount == 0)
        #expect(fajrBreakdown.pausedCount == 0)
        #expect(fajrBreakdown.markedPrayedCount == 0)
    }
}
