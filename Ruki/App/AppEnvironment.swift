import Foundation
import SwiftData
import UserNotifications

/// The app's composition root: builds every `Core/` dependency exactly once
/// at launch and hands the results to the views that need them. Nothing
/// outside this type constructs a real `ClockProviding`, `PersistenceProviding`,
/// or notification/background-refresh wrapper.
@MainActor
final class AppEnvironment {
    let clock: any ClockProviding
    let userSettings: UserSettings
    private let historyStores: HistoryStores

    /// The signed-in account's history, or the signed-out person's. Computed so
    /// every read follows the current login; screens that hold one are rebuilt
    /// when the owner changes (`historyOwnerKey` in `RootView`).
    var historyStore: HistoryStore {
        historyStores.store(for: currentHistoryOwner, now: clock.now())
    }

    var historyOwnerKey: String { currentHistoryOwner.key }

    private var currentHistoryOwner: HistoryOwner {
        social.account.map { .account(userID: $0.userID) } ?? .guest
    }
    let notificationAuthorizer: any NotificationAuthorizing
    let cameraProvider: any CameraProviding
    let router: AppRouter
    let social = SocialSession()

    private let persistence: any PersistenceProviding
    private let notificationScheduler: any NotificationScheduling
    private let backgroundRefreshScheduler: any BackgroundRefreshScheduling
    /// Held here, not just assigned as the delegate, because
    /// `UNUserNotificationCenter.delegate` is `weak` — nothing else in the
    /// app keeps this alive otherwise (RUKI-014).
    private let notificationCoordinator: NotificationCoordinator

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
        // D37: "a purge runs on launch/refresh" — this is the one call site
        // launch, foreground, and background wake all already share, so it's
        // also where expired photo data actually gets dropped. Previously
        // declared but never called anywhere (RUKI-037's purge existed only
        // as dead code); fixed here rather than leaving photos on-device
        // past their documented expiry (RDP-5).
        // Every account's store, not just the active one: expired photos shouldn't outlive their
        // expiry because their owner happens to be logged out.
        let now = clock.now()
        for store in historyStores.allStores(now: now) { try? store.purgeExpiredPhotos(now: now) }

        let inputs = userSettings.promptInputs
        try? await backgroundRefresh.refreshAndScheduleNext(inputs: inputs)
    }

    /// RUKI-037: "Delete my data on this device". Wipes on-device history,
    /// cancels every pending prompt outright (a re-plan would just schedule
    /// fresh ones against the reset-but-still-enabled defaults), then resets
    /// settings — which sends the router back to onboarding.
    /// Returns `false`, having changed nothing else, if the history wipe fails.
    /// Resetting settings after a failed wipe would send the person back to
    /// onboarding as if their data were gone while it was still on the device —
    /// the wrong way to fail a "delete my data" control. Clearing pending
    /// prompts is best-effort: a leftover prompt is not personal data.
    func deleteAllOnDeviceData() async -> Bool {
        // Server first: if it can't be reached nothing has changed, and the
        // person isn't told their data is gone while it still sits there.
        guard await social.deleteAccount() else { return false }
        do {
            // The whole device: every account's history, not just the one logged in.
            for store in historyStores.allStores(now: clock.now()) { try store.deleteAll() }
        } catch {
            return false
        }
        try? await notificationScheduler.replacePending(with: [], soundEnabled: userSettings.soundEnabled)
        userSettings.resetToDefaults()
        return true
    }

    /// T3 DEBUG tools: fires one real local notification ~10 seconds out,
    /// through the same `UNUserNotificationCenter` pipeline as a real
    /// prompt, without touching the real prompt horizon. Only ever called
    /// from Settings' `#if DEBUG`-gated section; harmless either way.
    func scheduleDebugTestPrompt() async {
        try? await notificationScheduler.scheduleTestPrompt(secondsFromNow: 10)
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

        #if targetEnvironment(simulator)
        // The Simulator has no camera at all — not a fallback path, a
        // different device entirely. `PlaceholderCameraProvider` keeps the
        // whole check-in flow exercisable there and in CI.
        cameraProvider = PlaceholderCameraProvider(clock: clock)
        #else
        cameraProvider = AVCameraProvider()
        #endif

        let userSettings = UserSettings()
        self.userSettings = userSettings
        self.router = AppRouter(userSettings: userSettings)

        persistence = Self.makePersistence()
        historyStores = HistoryStores(guestContainer: persistence.modelContainer)

        notificationScheduler = UserNotificationScheduler()
        notificationAuthorizer = SystemNotificationAuthorizer()
        backgroundRefreshScheduler = SystemBackgroundRefreshScheduler()

        notificationCoordinator = NotificationCoordinator(router: router)
        UNUserNotificationCenter.current().delegate = notificationCoordinator
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
