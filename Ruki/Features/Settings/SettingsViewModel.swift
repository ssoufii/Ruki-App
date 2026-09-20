import Foundation
import Observation

/// RUKI-036: backs `SettingsView`. Every setter writes straight through to
/// `UserSettings` (already `@Observable` and persisted) and re-plans the
/// notification horizon for whichever changes actually affect it — madhab
/// (Asr's time moves), which prayers prompt, and the sound. Window length
/// and Space Only default don't change *when* a prompt fires, only what
/// happens after it, so they don't trigger a re-plan.
@MainActor
@Observable
final class SettingsViewModel {
    private let userSettings: UserSettings
    private let notificationAuthorizer: any NotificationAuthorizing
    private let historyStore: HistoryStore
    private let clock: any ClockProviding
    private let onScheduleAffectingChange: () async -> Void

    private(set) var notificationStatus: NotificationAuthorizationStatus = .notDetermined
    private(set) var isPaused = false
    private(set) var loadError: (any Error)?

    var madhab: Madhab {
        get { userSettings.madhab }
        set {
            userSettings.madhab = newValue
            Task { await onScheduleAffectingChange() }
        }
    }

    var checkInWindowMinutes: Int {
        get { userSettings.checkInWindowMinutes }
        set { userSettings.checkInWindowMinutes = newValue }
    }

    var soundEnabled: Bool {
        get { userSettings.soundEnabled }
        set {
            userSettings.soundEnabled = newValue
            Task { await onScheduleAffectingChange() }
        }
    }

    var spaceOnlyDefault: Bool {
        get { userSettings.spaceOnlyDefault }
        set { userSettings.spaceOnlyDefault = newValue }
    }

    init(
        userSettings: UserSettings,
        notificationAuthorizer: any NotificationAuthorizing,
        historyStore: HistoryStore,
        clock: any ClockProviding,
        onScheduleAffectingChange: @escaping () async -> Void
    ) {
        self.userSettings = userSettings
        self.notificationAuthorizer = notificationAuthorizer
        self.historyStore = historyStore
        self.clock = clock
        self.onScheduleAffectingChange = onScheduleAffectingChange
    }

    /// Refreshes both the notification-permission status (which only the
    /// system knows) and whether a pause is active right now. Neither is
    /// `@Observable`-tracked from elsewhere, so the view calls this on
    /// appear rather than it being kept live automatically.
    func refresh() async {
        notificationStatus = await notificationAuthorizer.currentStatus()
        do {
            let pauses = try historyStore.pauseSnapshots()
            isPaused = pauses.contains { $0.isActive(at: clock.now()) }
            loadError = nil
        } catch {
            loadError = error
        }
    }

    /// Same two-tap flow as `TodayView`'s pause button (PRD §7.8: Settings
    /// is one of the two places pause is reachable from) — but unlike
    /// `TodayViewModel.pause(for:)`, this one re-plans notifications itself
    /// rather than leaving it to the caller, since `SettingsView` has no
    /// other reason to reach into `AppEnvironment` directly.
    func pause(for duration: PauseDuration) {
        let now = clock.now()
        do {
            try historyStore.recordPause(startedAt: now, endsAt: duration.endsAt(from: now))
            isPaused = true
        } catch {
            loadError = error
        }
        Task { await onScheduleAffectingChange() }
    }

    func isPrayerEnabled(_ prayer: Prayer) -> Bool {
        userSettings.enabledPrayers.contains(prayer)
    }

    /// RUKI-017: each prayer toggles independently. Refuses to leave every
    /// prayer disabled -- an empty schedule isn't a state the app should let
    /// someone stumble into with one tap.
    func setPrayer(_ prayer: Prayer, enabled: Bool) {
        var enabledPrayers = userSettings.enabledPrayers
        if enabled {
            enabledPrayers.insert(prayer)
        } else {
            guard enabledPrayers.count > 1 else { return }
            enabledPrayers.remove(prayer)
        }
        userSettings.enabledPrayers = enabledPrayers
        Task { await onScheduleAffectingChange() }
    }
}
