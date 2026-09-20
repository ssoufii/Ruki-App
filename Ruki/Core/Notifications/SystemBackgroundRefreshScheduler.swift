import BackgroundTasks
import Foundation

/// The real `BackgroundRefreshScheduling`, wrapping `BGTaskScheduler`.
///
/// `@unchecked Sendable`: `BackgroundTasks` hasn't audited `BGTaskScheduler`
/// for `Sendable`, but — same reasoning as `UserNotificationScheduler` for
/// `UNUserNotificationCenter` — it's a shared singleton (`.shared`) Apple's
/// own docs call from background contexts, and this wrapper holds nothing
/// else that needs synchronizing.
final class SystemBackgroundRefreshScheduler: BackgroundRefreshScheduling, @unchecked Sendable {
    private let scheduler: BGTaskScheduler

    init(scheduler: BGTaskScheduler = .shared) {
        self.scheduler = scheduler
    }

    func submit(identifier: String, earliestBeginDate: Date) async throws {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        try scheduler.submit(request)
    }
}
