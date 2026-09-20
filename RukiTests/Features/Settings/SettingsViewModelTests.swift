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
        onScheduleAffectingChange: @escaping () async -> Void = {},
        onDeleteAllData: @escaping () async -> Void = {}
    ) throws -> (SettingsViewModel, HistoryStore) {
        let historyStore = HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        let viewModel = SettingsViewModel(
            userSettings: userSettings ?? UserSettings(defaults: freshDefaults()),
            notificationAuthorizer: authorizer,
            historyStore: historyStore,
            clock: FixedClock(date: referenceDate),
            onScheduleAffectingChange: onScheduleAffectingChange,
            onDeleteAllData: onDeleteAllData
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
        try await Task.sleep(for: .milliseconds(10))
        #expect(await recorder.count == 1)
    }

    @Test("Changing the check-in window writes through without triggering a schedule refresh")
    func changingWindowDoesNotRefreshSchedule() async throws {
        let userSettings = UserSettings(defaults: freshDefaults())
        let recorder = RefreshRecorder()
        let (viewModel, _) = try makeViewModel(userSettings: userSettings, onScheduleAffectingChange: { await recorder.record() })

        viewModel.checkInWindowMinutes = 10

        #expect(userSettings.checkInWindowMinutes == 10)
        try await Task.sleep(for: .milliseconds(10))
        #expect(await recorder.count == 0)
    }

    @Test("Disabling a prayer removes it from enabledPrayers and triggers a refresh")
    func disablingAPrayerWritesThroughAndRefreshes() async throws {
        let userSettings = UserSettings(defaults: freshDefaults())
        let recorder = RefreshRecorder()
        let (viewModel, _) = try makeViewModel(userSettings: userSettings, onScheduleAffectingChange: { await recorder.record() })

        viewModel.setPrayer(.fajr, enabled: false)

        #expect(viewModel.isPrayerEnabled(.fajr) == false)
        #expect(userSettings.enabledPrayers.contains(.fajr) == false)
        try await Task.sleep(for: .milliseconds(10))
        #expect(await recorder.count == 1)
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
        try await Task.sleep(for: .milliseconds(10))
        #expect(await recorder.count == 0)
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
        try await Task.sleep(for: .milliseconds(10))
        #expect(await recorder.count == 1)
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
        let (viewModel, _) = try makeViewModel(onDeleteAllData: { await recorder.record() })

        viewModel.deleteAllData()

        try await Task.sleep(for: .milliseconds(10))
        #expect(await recorder.count == 1)
    }
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
