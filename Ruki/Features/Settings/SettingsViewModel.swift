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
    private let onDeleteAllData: () async -> Void
    /// T3 DEBUG tools only: fires a one-off test notification. Threaded
    /// unconditionally through init like every other callback here — the
    /// Settings section that ever calls it is `#if DEBUG`-gated, so this is
    /// simply unused in a release build, not unsafe to have.
    private let onDebugSendTestPrompt: () async -> Void

    private(set) var notificationStatus: NotificationAuthorizationStatus = .notDetermined
    private(set) var isPaused = false
    /// RUKI-037: a fresh local JSON file of everything `HistoryStore` holds
    /// (minus photos — D37), rewritten every `refresh()`. `nil` only if the
    /// export itself failed, which `loadError` explains.
    private(set) var exportFileURL: URL?
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
        onScheduleAffectingChange: @escaping () async -> Void,
        onDeleteAllData: @escaping () async -> Void,
        onDebugSendTestPrompt: @escaping () async -> Void = {}
    ) {
        self.userSettings = userSettings
        self.notificationAuthorizer = notificationAuthorizer
        self.historyStore = historyStore
        self.clock = clock
        self.onScheduleAffectingChange = onScheduleAffectingChange
        self.onDeleteAllData = onDeleteAllData
        self.onDebugSendTestPrompt = onDebugSendTestPrompt
    }

    /// Refreshes the notification-permission status (which only the system
    /// knows), whether a pause is active right now, and the export file.
    /// None of these is `@Observable`-tracked from elsewhere, so the view
    /// calls this on appear rather than it being kept live automatically.
    func refresh() async {
        notificationStatus = await notificationAuthorizer.currentStatus()
        do {
            let pauses = try historyStore.pauseSnapshots()
            isPaused = pauses.contains { $0.isActive(at: clock.now()) }
            exportFileURL = try Self.writeExportFile(historyStore: historyStore, now: clock.now())
            loadError = nil
        } catch {
            loadError = error
        }
    }

    /// RUKI-037: "Delete my data on this device" — forwarded to
    /// `AppEnvironment`, which owns SwiftData, `UserSettings`, and the
    /// notification scheduler, none of which this view model holds all of.
    /// The confirmation step lives in `SettingsView`; by the time this is
    /// called the user has already agreed.
    func deleteAllData() {
        Task { await onDeleteAllData() }
    }

    /// A fresh temp file each call rather than a cached one: cheap (this
    /// data is small), and it means the export is never stale by the time
    /// the person actually taps share.
    private static func writeExportFile(historyStore: HistoryStore, now: Date) throws -> URL {
        let export = try historyStore.exportSnapshot(exportedAt: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ruki-export-\(TorontoCalendar.dayKey(for: now))")
            .appendingPathExtension("json")
        try data.write(to: url, options: .atomic)
        return url
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

    #if DEBUG
    /// `nil` on `SystemClock`, which release builds always use — `clock`
    /// only ever becomes an `OffsetClock` under `#if DEBUG` in
    /// `AppEnvironment.init()`. The Settings section that reads this is
    /// itself `#if DEBUG`-gated, so this is belt-and-suspenders, not the
    /// only thing keeping it out of a release build.
    var debugClockIsShifted: Bool {
        (clock as? OffsetClock)?.isShifted ?? false
    }

    /// T3: jumps the DEBUG clock straight to a named scenario instead of
    /// waiting for the real adhan.
    func debugJump(to scenario: DebugClockScenario) {
        (clock as? OffsetClock)?.jump(to: scenario.date(referenceNow: clock.now()))
    }

    /// T3: back to the real wall clock.
    func debugResetClock() {
        (clock as? OffsetClock)?.reset()
    }

    /// T3: fires a real one-off local notification ~10 seconds out, through
    /// the actual `UNUserNotificationCenter` pipeline, to verify delivery on
    /// a device without disturbing the real prompt horizon.
    func debugSendTestPrompt() {
        Task { await onDebugSendTestPrompt() }
    }
    #endif
}
