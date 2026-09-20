import Foundation

/// Coordinates planning and scheduling: the one call site that turns "here
/// are the upcoming slots" into pending notifications actually being
/// requested. Doesn't touch permissions itself — call `NotificationAuthorizing`
/// first and only refresh if authorized.
struct PromptScheduler: Sendable {
    let planner: PromptPlanner
    let scheduler: any NotificationScheduling

    init(planner: PromptPlanner = PromptPlanner(), scheduler: any NotificationScheduling) {
        self.planner = planner
        self.scheduler = scheduler
    }

    func refresh(slots: [PrayerSlot], enabledPrayers: Set<Prayer>, soundEnabled: Bool) async throws {
        let specs = planner.plan(for: slots, enabledPrayers: enabledPrayers)
        try await scheduler.replacePending(with: specs, soundEnabled: soundEnabled)
    }
}
