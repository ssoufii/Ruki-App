import Foundation

/// Ties the 12-day scheduling horizon (`PromptRefreshCoordinator`) to
/// `BGTaskScheduler` (RUKI-015): the one call a background-refresh launch
/// handler needs to make. Registering that launch handler itself happens
/// via SwiftUI's `.backgroundTask(.appRefresh(_:))` modifier on a `Scene` —
/// it needs the app shell (RUKI T1), not yet built — which is expected to
/// call `refreshAndScheduleNext` here and nothing more.
struct BackgroundRefresh: Sendable {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in `Ruki-Info.plist`.
    static let taskIdentifier = "com.salimsoufi.Ruki.refresh-prompts"

    /// How soon to ask for the next background wake-up after this one. Not
    /// a delivery guarantee — iOS decides if and when it actually fires.
    /// 24h is a starting point, not a tuned decision: it keeps the pending
    /// set topped up comfortably inside the 12-day horizon even if several
    /// wake-ups in a row never happen.
    static let refreshInterval: TimeInterval = 24 * 60 * 60

    let coordinator: PromptRefreshCoordinator
    let scheduler: any BackgroundRefreshScheduling

    /// Refreshes the pending notifications, then requests the next
    /// background wake-up. Also what app-launch, foreground, a settings
    /// change, or a pause change should call directly (no background-task
    /// machinery needed there) — those hooks land with the app shell (T1)
    /// and the screens that own each trigger (T2, RUKI-034).
    func refreshAndScheduleNext(inputs: PromptInputs) async throws {
        try await coordinator.refresh(inputs: inputs)
        try await scheduler.submit(
            identifier: Self.taskIdentifier,
            earliestBeginDate: coordinator.clock.now().addingTimeInterval(Self.refreshInterval)
        )
    }
}
