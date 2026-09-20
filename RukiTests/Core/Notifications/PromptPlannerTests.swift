import Foundation
import Testing
@testable import Ruki

@Suite("PromptPlanner")
struct PromptPlannerTests {
    private let planner = PromptPlanner()
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T09:00:00Z")!

    private func slot(prayer: Prayer, daysFromReference: Int) -> PrayerSlot {
        let start = referenceDate.addingTimeInterval(TimeInterval(daysFromReference * 86400))
        let window = PrayerWindow(
            prayer: prayer,
            madhab: .standard,
            start: start,
            checkInWindowEnd: start.addingTimeInterval(1800),
            end: start.addingTimeInterval(3600)
        )
        return PrayerSlot(window: window)
    }

    @Test("A spec is produced for every slot, firing at the slot's adhan (RUKI-013)")
    func producesOneSpecPerSlotFiringAtAdhan() {
        let slots = [slot(prayer: .fajr, daysFromReference: 0), slot(prayer: .dhuhr, daysFromReference: 0)]
        let specs = planner.plan(for: slots)
        #expect(specs.count == 2)
        #expect(specs.allSatisfy { spec in slots.contains { $0.window.start == spec.fireDate } })
    }

    @Test("Every spec's identifier carries the ruki.prompt. prefix")
    func specIdentifiersCarryThePrefix() {
        let specs = planner.plan(for: [slot(prayer: .fajr, daysFromReference: 0)])
        #expect(specs.allSatisfy { $0.id.hasPrefix("ruki.prompt.") })
    }

    @Test("Disabled prayers are excluded from the plan (RUKI-017)")
    func disabledPrayersAreExcluded() {
        let slots = [slot(prayer: .fajr, daysFromReference: 0), slot(prayer: .dhuhr, daysFromReference: 0)]
        let specs = planner.plan(for: slots, enabledPrayers: [.dhuhr])
        #expect(specs.map(\.prayer) == [.dhuhr])
    }

    @Test("Specs come out sorted by fire date regardless of input order")
    func specsAreSortedByFireDate() {
        let slots = [
            slot(prayer: .isha, daysFromReference: 1),
            slot(prayer: .fajr, daysFromReference: 0),
            slot(prayer: .dhuhr, daysFromReference: 0),
        ]
        let specs = planner.plan(for: slots)
        #expect(specs.map(\.fireDate) == specs.map(\.fireDate).sorted())
    }

    @Test("The plan never exceeds iOS's 64-pending ceiling, even given more slots (RUKI-016)")
    func planCapsAtSixtyFour() {
        let manySlots = (0..<20).flatMap { day in
            Prayer.allCases.map { slot(prayer: $0, daysFromReference: day) }
        }
        #expect(manySlots.count == 100)
        let specs = planner.plan(for: manySlots)
        #expect(specs.count == PromptPlanner.maxPending)
    }

    @Test("When capped, the plan keeps the earliest-firing notifications, not an arbitrary subset")
    func capKeepsEarliestSlots() {
        let manySlots = (0..<20).flatMap { day in
            Prayer.allCases.map { slot(prayer: $0, daysFromReference: day) }
        }
        let expectedFireDates = Array(manySlots.map(\.window.start).sorted().prefix(PromptPlanner.maxPending))
        let specs = planner.plan(for: manySlots)
        #expect(specs.map(\.fireDate) == expectedFireDates)
    }
}
