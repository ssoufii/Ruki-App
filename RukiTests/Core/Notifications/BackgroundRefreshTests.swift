import Foundation
import Testing
@testable import Ruki

@Suite("BackgroundRefresh")
struct BackgroundRefreshTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T09:00:00Z")!

    private func makeBackgroundRefresh(
        promptScheduler: PromptScheduler,
        backgroundScheduler: FakeBackgroundRefreshScheduler
    ) -> BackgroundRefresh {
        let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard)
        let clock = FixedClock(date: referenceDate)
        let coordinator = PromptRefreshCoordinator(timeline: timeline, clock: clock, promptScheduler: promptScheduler)
        return BackgroundRefresh(coordinator: coordinator, scheduler: backgroundScheduler)
    }

    @Test("refreshAndScheduleNext refreshes prompts, then requests the next wake-up using this app's own task identifier")
    func refreshesThenSchedulesNext() async throws {
        let notificationFake = FakeNotificationScheduler()
        let backgroundFake = FakeBackgroundRefreshScheduler()
        let backgroundRefresh = makeBackgroundRefresh(
            promptScheduler: PromptScheduler(scheduler: notificationFake),
            backgroundScheduler: backgroundFake
        )

        try await backgroundRefresh.refreshAndScheduleNext(inputs: PromptInputs(enabledPrayers: Set(Prayer.allCases), soundEnabled: true))

        let scheduled = await notificationFake.scheduled
        #expect(!scheduled.isEmpty)

        let submitted = await backgroundFake.submitted
        #expect(submitted.count == 1)
        #expect(submitted.first?.identifier == BackgroundRefresh.taskIdentifier)
        #expect(submitted.first?.earliestBeginDate == referenceDate.addingTimeInterval(BackgroundRefresh.refreshInterval))
    }

    @Test("A submission failure propagates rather than being swallowed")
    func submissionFailurePropagates() async throws {
        let notificationFake = FakeNotificationScheduler()
        let backgroundFake = FakeBackgroundRefreshScheduler()
        await backgroundFake.setShouldThrow()
        let backgroundRefresh = makeBackgroundRefresh(
            promptScheduler: PromptScheduler(scheduler: notificationFake),
            backgroundScheduler: backgroundFake
        )

        await #expect(throws: FakeBackgroundRefreshScheduler.SubmissionError.self) {
            try await backgroundRefresh.refreshAndScheduleNext(inputs: PromptInputs(enabledPrayers: Set(Prayer.allCases), soundEnabled: true))
        }

        // The refresh itself still went through before the submission failed.
        let scheduled = await notificationFake.scheduled
        #expect(!scheduled.isEmpty)
    }
}
