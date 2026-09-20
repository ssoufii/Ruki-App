import Foundation
import SwiftData

/// The app's composition root: builds every `Core/` dependency exactly once
/// at launch and hands the results to the views that need them. Nothing
/// outside this type constructs a real `ClockProviding`, `PersistenceProviding`,
/// or notification/background-refresh wrapper.
@MainActor
final class AppEnvironment {
    let clock: any ClockProviding
    let userSettings: UserSettings
    let historyStore: HistoryStore
    let notificationAuthorizer: any NotificationAuthorizing
    let router: AppRouter

    private let persistence: any PersistenceProviding
    private let notificationScheduler: any NotificationScheduling
    private let backgroundRefreshScheduler: any BackgroundRefreshScheduling

    /// The current prayer timeline. A computed property, not stored, so a
    /// later madhab change in `userSettings` (RUKI-036 Settings) is picked
    /// up immediately rather than needing the whole environment rebuilt.
    var timeline: PrayerTimeline {
        PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: userSettings.madhab)
    }

    /// The one call a background-task launch handler (wired up with the app
    /// shell's `.backgroundTask(.appRefresh(_:))`, once something calls it)
    /// needs to make. Computed for the same reason `timeline` is: it must
    /// never schedule against a stale madhab or enabled-prayers set.
    var backgroundRefresh: BackgroundRefresh {
        let coordinator = PromptRefreshCoordinator(
            timeline: timeline,
            clock: clock,
            promptScheduler: PromptScheduler(scheduler: notificationScheduler)
        )
        return BackgroundRefresh(coordinator: coordinator, scheduler: backgroundRefreshScheduler)
    }

    /// Re-plans the 12-day notification horizon (RUKI-015) against whatever's
    /// currently enabled. `RukiApp` calls this on launch, foreground, and
    /// background wake; a settings or pause change (RUKI-036, RUKI-034)
    /// calls it the same way, right after writing the change that affects
    /// scheduling.
    func refreshBackgroundSchedule() async {
        let inputs = userSettings.promptInputs
        try? await backgroundRefresh.refreshAndScheduleNext(inputs: inputs)
    }

    init() {
        #if DEBUG
        // A tester can jump the clock (DEBUG tools, T3) instead of waiting
        // for the real adhan; release builds only ever see `SystemClock`.
        let clock: any ClockProviding = OffsetClock()
        #else
        let clock: any ClockProviding = SystemClock()
        #endif
        self.clock = clock

        let userSettings = UserSettings()
        self.userSettings = userSettings
        self.router = AppRouter(userSettings: userSettings)

        persistence = Self.makePersistence()
        historyStore = HistoryStore(modelContainer: persistence.modelContainer)

        notificationScheduler = UserNotificationScheduler()
        notificationAuthorizer = SystemNotificationAuthorizer()
        backgroundRefreshScheduler = SystemBackgroundRefreshScheduler()
    }

    /// Falls back to an in-memory store rather than crashing if the
    /// persistent container can't be opened (full disk, a corrupted store).
    /// Never `fatalError` in a shipping path (CLAUDE.md) — losing this
    /// launch's history to a degraded in-memory session is the honest
    /// alternative; the persistent path is retried next launch.
    private static func makePersistence() -> any PersistenceProviding {
        if let persistence = try? SwiftDataPersistence() {
            return persistence
        }
        // In-memory, with the app's own fixed schema, has no realistic
        // failure mode the way an on-disk container does.
        return try! SwiftDataPersistence(inMemory: true)
    }
}
