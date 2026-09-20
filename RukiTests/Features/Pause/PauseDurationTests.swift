import Foundation
import Testing
@testable import Ruki

@Suite("PauseDuration")
struct PauseDurationTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T18:00:00Z")!

    @Test("\"Today\" ends at the start of tomorrow (Toronto), never leaking into the next day")
    func todayEndsAtStartOfTomorrow() throws {
        let endsAt = try #require(PauseDuration.today.endsAt(from: referenceDate))
        #expect(endsAt == TorontoCalendar.startOfDay(byAdding: 1, to: referenceDate))
    }

    @Test("A 3-day pause ends 3 days after now")
    func threeDaysEndsThreeDaysLater() throws {
        let endsAt = try #require(PauseDuration.threeDays.endsAt(from: referenceDate))
        #expect(endsAt == referenceDate.addingTimeInterval(3 * 24 * 60 * 60))
    }

    @Test("A 7-day pause ends 7 days after now")
    func sevenDaysEndsSevenDaysLater() throws {
        let endsAt = try #require(PauseDuration.sevenDays.endsAt(from: referenceDate))
        #expect(endsAt == referenceDate.addingTimeInterval(7 * 24 * 60 * 60))
    }

    @Test("A 10-day pause ends 10 days after now")
    func tenDaysEndsTenDaysLater() throws {
        let endsAt = try #require(PauseDuration.tenDays.endsAt(from: referenceDate))
        #expect(endsAt == referenceDate.addingTimeInterval(10 * 24 * 60 * 60))
    }

    @Test("\"Until I turn it back on\" has no end date")
    func untilResumedHasNoEndDate() {
        #expect(PauseDuration.untilResumed.endsAt(from: referenceDate) == nil)
    }

    @Test("Every duration has a non-empty, distinct label")
    func everyDurationHasADistinctLabel() {
        let labels = PauseDuration.allCases.map(\.label)
        #expect(Set(labels).count == labels.count)
        #expect(labels.allSatisfy { !$0.isEmpty })
    }
}
