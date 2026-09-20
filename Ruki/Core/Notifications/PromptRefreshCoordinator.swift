import Foundation

/// Turns "refresh what's scheduled, right now" into the actual horizon of
/// slots to hand `PromptScheduler` (RUKI-015): everything from `now` through
/// `horizonDays` calendar days out, excluding whatever's already passed
/// today so a stale refresh can't re-request a notification for a prayer
/// that's already over.
struct PromptRefreshCoordinator: Sendable {
    /// 12 days × 5 prayers = 60, comfortably under `PromptPlanner.maxPending`
    /// (64, RUKI-016) even before any prayer is disabled (RUKI-017).
    static let horizonDays = 12

    let timeline: PrayerTimeline
    let clock: any ClockProviding
    let promptScheduler: PromptScheduler

    func refresh(inputs: PromptInputs) async throws {
        try await promptScheduler.refresh(slots: upcomingSlots(), inputs: inputs)
    }

    /// Exposed separately from `refresh` so a test (or a future caller that
    /// wants the count before deciding whether to bother) can inspect the
    /// horizon without going through a real `PromptScheduler`.
    func upcomingSlots() -> [PrayerSlot] {
        let now = clock.now()
        let horizonEnd = TorontoCalendar.startOfDay(byAdding: Self.horizonDays, to: now)
        return timeline.slots(from: now, through: horizonEnd).filter { $0.window.start > now }
    }
}
