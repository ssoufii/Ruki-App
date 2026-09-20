import Foundation
import Testing
@testable import Ruki

@MainActor
@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!

    private func freshDefaults() -> UserDefaults {
        let suiteName = "SettingsViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeViewModel(
        userSettings: UserSettings? = nil,
        authorizer: any NotificationAuthorizing = FakeNotificationAuthorizer(),
        clock: any ClockProviding = FixedClock(date: ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!),
        onScheduleAffectingChange: @escaping () async -> Void = {},
        onDeleteAllData: @escaping () async -> Bool = { true },
        onDebugSendTestPrompt: @escaping () async -> Void = {}
    ) throws -> (SettingsViewModel, HistoryStore) {
        let historyStore = HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        let viewModel = SettingsViewModel(
            userSettings: userSettings ?? UserSettings(defaults: freshDefaults()),
            notificationAuthorizer: authorizer,
            historyStore: historyStore,
            clock: clock,
            onScheduleAffectingChange: onScheduleAffectingChange,
            onDeleteAllData: onDeleteAllData,
            onDebugSendTestPrompt: onDebugSendTestPrompt
        )
        return (viewModel, historyStore)
    }

    @Test("Changing madhab writes straight through to UserSettings and triggers a schedule refresh")
    func changingMadhabWritesThroughAndRefreshes() async throws {
        let userSettings = UserSettings(defaults: freshDefaults())
        let recorder = RefreshRecorder()
        let (viewModel, _) = try makeViewModel(userSettings: userSettings, onScheduleAffectingChange: { await recorder.record() })

        viewModel.madhab = .hanafi

        #expect(userSettings.madhab == .hanafi)
        #expect(await waitUntil { await recorder.count == 1 })
    }

    @Test("Changing the check-in window writes through without triggering a schedule refresh")
    func changingWindowDoesNotRefreshSchedule() async throws {
        let userSettings = UserSettings(defaults: freshDefaults())
        let recorder = RefreshRecorder()
        let (viewModel, _) = try makeViewModel(userSettings: userSettings, onScheduleAffectingChange: { await recorder.record() })

        viewModel.checkInWindowMinutes = 10

        #expect(userSettings.checkInWindowMinutes == 10)
        // Barrier: a change that DOES refresh. Once its refresh has landed, any
        // refresh wrongly triggered by the change above would already be counted.
        viewModel.madhab = .hanafi
        #expect(await waitUntil { await recorder.count >= 1 })
        try await Task.sleep(for: .milliseconds(50))
        #expect(await recorder.count == 1, "only the barrier's refresh should have run")
    }

    @Test("Disabling a prayer removes it from enabledPrayers and triggers a refresh")
    func disablingAPrayerWritesThroughAndRefreshes() async throws {
        let userSettings = UserSettings(defaults: freshDefaults())
        let recorder = RefreshRecorder()
        let (viewModel, _) = try makeViewModel(userSettings: userSettings, onScheduleAffectingChange: { await recorder.record() })

        viewModel.setPrayer(.fajr, enabled: false)

        #expect(viewModel.isPrayerEnabled(.fajr) == false)
        #expect(userSettings.enabledPrayers.contains(.fajr) == false)
        #expect(await waitUntil { await recorder.count == 1 })
    }

    @Test("Disabling every prayer is refused -- at least one must stay enabled")
    func disablingEveryPrayerIsRefused() throws {
        let userSettings = UserSettings(defaults: freshDefaults())
        for prayer in Prayer.allCases where prayer != .isha {
            userSettings.enabledPrayers.remove(prayer)
        }
        let (viewModel, _) = try makeViewModel(userSettings: userSettings)

        viewModel.setPrayer(.isha, enabled: false)

        #expect(userSettings.enabledPrayers == [.isha])
    }

    @Test("Space Only default writes through without triggering a schedule refresh")
    func spaceOnlyDefaultDoesNotRefreshSchedule() async throws {
        let userSettings = UserSettings(defaults: freshDefaults())
        let recorder = RefreshRecorder()
        let (viewModel, _) = try makeViewModel(userSettings: userSettings, onScheduleAffectingChange: { await recorder.record() })

        viewModel.spaceOnlyDefault = true

        #expect(userSettings.spaceOnlyDefault == true)
        // Barrier: a change that DOES refresh. Once its refresh has landed, any
        // refresh wrongly triggered by the change above would already be counted.
        viewModel.madhab = .hanafi
        #expect(await waitUntil { await recorder.count >= 1 })
        try await Task.sleep(for: .milliseconds(50))
        #expect(await recorder.count == 1, "only the barrier's refresh should have run")
    }

    @Test("refresh() reads the current notification authorization status")
    func refreshReadsNotificationStatus() async throws {
        let (viewModel, _) = try makeViewModel(authorizer: FakeNotificationAuthorizer(statusToReturn: .denied))

        await viewModel.refresh()

        #expect(viewModel.notificationStatus == .denied)
    }

    @Test("refresh() reports no active pause when there is none")
    func refreshReportsNotPausedByDefault() async throws {
        let (viewModel, _) = try makeViewModel()

        await viewModel.refresh()

        #expect(viewModel.isPaused == false)
    }

    @Test("refresh() reports an active pause that covers now")
    func refreshReportsActivePause() async throws {
        let (viewModel, historyStore) = try makeViewModel()
        try historyStore.recordPause(startedAt: referenceDate.addingTimeInterval(-3600), endsAt: nil)

        await viewModel.refresh()

        #expect(viewModel.isPaused == true)
    }

    @Test("Pausing from Settings records the pause and triggers a schedule refresh")
    func pausingRecordsPauseAndRefreshes() async throws {
        let recorder = RefreshRecorder()
        let (viewModel, historyStore) = try makeViewModel(onScheduleAffectingChange: { await recorder.record() })

        viewModel.pause(for: .threeDays)

        #expect(viewModel.isPaused == true)
        let pauses = try historyStore.pauseSnapshots()
        #expect(pauses.count == 1)
        #expect(pauses.first?.endsAt == referenceDate.addingTimeInterval(3 * 24 * 60 * 60))
        #expect(await waitUntil { await recorder.count == 1 })
    }

    @Test("Resuming from Settings ends the active pause and triggers a schedule refresh (RDP-3)")
    func resumingEndsPauseAndRefreshes() async throws {
        let recorder = RefreshRecorder()
        let (viewModel, historyStore) = try makeViewModel(onScheduleAffectingChange: { await recorder.record() })
        try historyStore.recordPause(startedAt: referenceDate.addingTimeInterval(-3600), endsAt: nil)
        await viewModel.refresh()
        #expect(viewModel.isPaused == true)

        viewModel.resume()

        #expect(viewModel.isPaused == false)
        let pauses = try historyStore.pauseSnapshots()
        #expect(pauses.first?.endsAt == referenceDate)
        #expect(await waitUntil { await recorder.count == 1 })
    }

    @Test("refresh() writes a JSON export file with no photo fields anywhere in it (RUKI-037, D37)")
    func refreshWritesExportFileWithoutPhotos() async throws {
        let (viewModel, historyStore) = try makeViewModel()
        let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard)
        let fajr = timeline.slots(onDayOf: referenceDate).first { $0.prayer == .fajr }!
        try historyStore.recordCheckIn(
            for: fajr, isLate: false, checkedInAt: referenceDate,
            frontImageData: Data([0x01, 0x02]), rearImageData: nil,
            expiresAt: referenceDate.addingTimeInterval(3600), caption: "alhamdulillah"
        )

        await viewModel.refresh()

        let url = try #require(viewModel.exportFileURL)
        let data = try Data(contentsOf: url)
        let export = try JSONDecoder().decoded(HistoryExport.self, from: data)
        #expect(export.checkIns.count == 1)
        #expect(export.checkIns.first?.caption == "alhamdulillah")
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.lowercased().contains("imagedata"))
    }

    @Test("Confirming delete forwards to onDeleteAllData -- AppEnvironment owns the actual wipe")
    func deleteAllDataForwardsToCallback() async throws {
        let recorder = RefreshRecorder()
        let (viewModel, _) = try makeViewModel(onDeleteAllData: { await recorder.record(); return true })

        viewModel.deleteAllData()

        #expect(await waitUntil { await recorder.count == 1 })
    }

    #if DEBUG
    @Test("A failed delete is reported, not swallowed -- the person must not be told their data is gone when it isn't")
    func failedDeleteIsSurfaced() async throws {
        let (viewModel, _) = try makeViewModel(onDeleteAllData: { false })

        viewModel.deleteAllData()

        #expect(await waitUntil { viewModel.deleteFailed })
    }

    @Test("A successful delete does not raise the failure alert")
    func successfulDeleteDoesNotRaiseAlert() async throws {
        let recorder = RefreshRecorder()
        let (viewModel, _) = try makeViewModel(onDeleteAllData: { await recorder.record(); return true })

        viewModel.deleteAllData()

        #expect(await waitUntil { await recorder.count == 1 })
        #expect(viewModel.deleteFailed == false)
    }

    @Test("debugJump moves an OffsetClock to the scenario's target instant")
    func debugJumpMovesOffsetClock() throws {
        let offsetClock = OffsetClock(base: FixedClock(date: referenceDate))
        let (viewModel, _) = try makeViewModel(clock: offsetClock)
        #expect(viewModel.debugClockIsShifted == false)

        viewModel.debugJump(to: .dhuhrJustBegan)

        #expect(viewModel.debugClockIsShifted == true)
        #expect(offsetClock.now() == DebugClockScenario.dhuhrJustBegan.date(referenceNow: referenceDate))
    }

    @Test("debugResetClock returns an OffsetClock to the real time")
    func debugResetClockUndoesTheJump() throws {
        let offsetClock = OffsetClock(base: FixedClock(date: referenceDate))
        let (viewModel, _) = try makeViewModel(clock: offsetClock)
        viewModel.debugJump(to: .ishaJustBegan)
        #expect(viewModel.debugClockIsShifted == true)

        viewModel.debugResetClock()

        #expect(viewModel.debugClockIsShifted == false)
        #expect(offsetClock.now() == referenceDate)
    }

    @Test("debugJump/debugResetClock are no-ops on a plain (non-Offset) clock, never a crash")
    func debugToolsAreNoOpsOnAPlainClock() throws {
        let (viewModel, _) = try makeViewModel(clock: FixedClock(date: referenceDate))

        viewModel.debugJump(to: .fajrOpen)
        viewModel.debugResetClock()

        #expect(viewModel.debugClockIsShifted == false)
    }

    @Test("debugSendTestPrompt forwards to onDebugSendTestPrompt")
    func debugSendTestPromptForwards() async throws {
        let recorder = RefreshRecorder()
        let (viewModel, _) = try makeViewModel(onDebugSendTestPrompt: { await recorder.record() })

        viewModel.debugSendTestPrompt()

        #expect(await waitUntil { await recorder.count == 1 })
    }
    #endif
}

private extension JSONDecoder {
    func decoded<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        dateDecodingStrategy = .iso8601
        return try decode(type, from: data)
    }
}

/// Counts how many times a schedule-refresh callback fired, without pulling
/// in the real `BackgroundRefresh`/`AppEnvironment` machinery this view
/// model only ever calls through a closure.
private actor RefreshRecorder {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
