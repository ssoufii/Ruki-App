import Foundation
import Testing
@testable import Ruki

@Suite("PromptScheduler")
struct PromptSchedulerTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T09:00:00Z")!

    private func slot(prayer: Prayer, daysFromReference: Int = 0) -> PrayerSlot {
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

    @Test("refresh(slots:) plans then hands the exact result to the underlying scheduler")
    func refreshPlansAndSchedules() async throws {
        let fake = FakeNotificationScheduler()
        let promptScheduler = PromptScheduler(scheduler: fake)
        let slots = [slot(prayer: .fajr), slot(prayer: .dhuhr)]

        try await promptScheduler.refresh(slots: slots, enabledPrayers: Set(Prayer.allCases), soundEnabled: true)

        let scheduled = await fake.scheduled
        #expect(scheduled.count == 2)
        #expect(await fake.lastSoundEnabled == true)
    }

    @Test("refresh(slots:) excludes prayers the user has disabled (RUKI-017)")
    func refreshHonoursEnabledPrayers() async throws {
        let fake = FakeNotificationScheduler()
        let promptScheduler = PromptScheduler(scheduler: fake)
        let slots = [slot(prayer: .fajr), slot(prayer: .dhuhr)]

        try await promptScheduler.refresh(slots: slots, enabledPrayers: [.dhuhr], soundEnabled: false)

        let scheduled = await fake.scheduled
        #expect(scheduled.map(\.prayer) == [.dhuhr])
        #expect(await fake.lastSoundEnabled == false)
    }

    @Test("A second refresh call replaces the first rather than accumulating (idempotent)")
    func refreshReplacesPreviousCall() async throws {
        let fake = FakeNotificationScheduler()
        let promptScheduler = PromptScheduler(scheduler: fake)

        try await promptScheduler.refresh(slots: [slot(prayer: .fajr)], enabledPrayers: Set(Prayer.allCases), soundEnabled: true)
        try await promptScheduler.refresh(slots: [slot(prayer: .dhuhr)], enabledPrayers: Set(Prayer.allCases), soundEnabled: true)

        let scheduled = await fake.scheduled
        #expect(scheduled.map(\.prayer) == [.dhuhr])
        #expect(await fake.replaceCallCount == 2)
    }
}

@Suite("NotificationScheduling ceiling")
struct NotificationSchedulingCeilingTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T09:00:00Z")!

    private func spec(index: Int) -> PromptSpec {
        let start = referenceDate.addingTimeInterval(TimeInterval(index * 3600))
        let window = PrayerWindow(
            prayer: .fajr, madhab: .standard, start: start,
            checkInWindowEnd: start.addingTimeInterval(1800), end: start.addingTimeInterval(3600)
        )
        return PromptSpec(slot: PrayerSlot(window: window))
    }

    @Test("The scheduler itself throws if handed more than 64 specs, even bypassing the planner (RUKI-016)")
    func schedulerThrowsAboveCeiling() async {
        let fake = FakeNotificationScheduler()
        let tooMany = (0..<65).map(spec)

        await #expect(throws: NotificationSchedulingError.tooManyPending(65)) {
            try await fake.replacePending(with: tooMany, soundEnabled: true)
        }
    }

    @Test("Exactly 64 specs is accepted")
    func schedulerAcceptsExactlySixtyFour() async throws {
        let fake = FakeNotificationScheduler()
        let exactlyMax = (0..<64).map(spec)
        try await fake.replacePending(with: exactlyMax, soundEnabled: true)
        #expect(await fake.pendingCount() == 64)
    }
}

@Suite("FakeNotificationAuthorizer")
struct NotificationAuthorizingTests {
    @Test("Requesting authorization grants and updates the reported status")
    func requestGrantsAndUpdatesStatus() async throws {
        let authorizer = FakeNotificationAuthorizer(statusToReturn: .notDetermined, grantOnRequest: true)
        let granted = try await authorizer.requestAuthorization()
        #expect(granted)
        #expect(await authorizer.currentStatus() == .authorized)
    }

    @Test("A denied request leaves the status as denied, not authorized")
    func deniedRequestDoesNotReportAuthorized() async throws {
        let authorizer = FakeNotificationAuthorizer(statusToReturn: .denied, grantOnRequest: false)
        let granted = try await authorizer.requestAuthorization()
        #expect(granted == false)
        #expect(await authorizer.currentStatus() != .authorized)
    }
}
