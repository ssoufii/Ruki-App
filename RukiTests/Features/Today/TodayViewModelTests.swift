import Foundation
import Testing
@testable import Ruki

@MainActor
@Suite("TodayViewModel")
struct TodayViewModelTests {
    // Toronto is UTC-4 in September (DST). Fajr 5:20/sunrise 6:52/Dhuhr 13:05/
    // Asr 16:35/Maghrib 19:15/Isha 20:40 local, per FixedPrayerTimeProvider.
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!

    private func freshDefaults() -> UserDefaults {
        let suiteName = "TodayViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeViewModel(now: Date, onboardingCompletedAt: Date? = nil) throws -> (TodayViewModel, HistoryStore, PrayerTimeline) {
        let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard)
        let userSettings = UserSettings(defaults: freshDefaults())
        userSettings.onboardingCompletedAt = onboardingCompletedAt ?? referenceDate.addingTimeInterval(-86_400)
        let historyStore = HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        let viewModel = TodayViewModel(
            timeline: timeline, clock: FixedClock(date: now), userSettings: userSettings, historyStore: historyStore
        )
        return (viewModel, historyStore, timeline)
    }

    @Test("Today's rows are all five prayers, in order, before any of them have opened")
    func rowsCoverAllFivePrayersInOrder() throws {
        let (viewModel, _, _) = try makeViewModel(now: ISO8601DateFormatter().date(from: "2026-09-19T08:00:00Z")!)
        viewModel.refresh()

        #expect(viewModel.rows.map(\.slot.prayer) == [.fajr, .dhuhr, .asr, .maghrib, .isha])
        #expect(viewModel.rows.allSatisfy { $0.status == .upcoming })
        #expect(viewModel.activeRow == nil)
    }

    @Test("An open prayer within its on-time cutoff shows as open, on time")
    func openOnTimeDuringFajr() throws {
        // 5:30 a.m. Toronto: ten minutes after Fajr's adhan, well before sunrise.
        let now = ISO8601DateFormatter().date(from: "2026-09-19T09:30:00Z")!
        let (viewModel, _, _) = try makeViewModel(now: now)
        viewModel.refresh()

        let fajrRow = try #require(viewModel.rows.first { $0.slot.prayer == .fajr })
        #expect(fajrRow.status == .openOnTime)
        #expect(viewModel.activeRow?.slot.prayer == .fajr)
        #expect(viewModel.headline.contains("Fajr"))
        #expect(viewModel.headline.contains("on time"))
    }

    @Test("Between prayer windows, the headline points to what's next with a gentle countdown")
    func headlineCountsDownToNextPrayerWhenNothingIsOpen() throws {
        // 12:55 p.m. Toronto: after sunrise, ten minutes before Dhuhr.
        let now = ISO8601DateFormatter().date(from: "2026-09-19T16:55:00Z")!
        let (viewModel, _, _) = try makeViewModel(now: now)
        viewModel.refresh()

        #expect(viewModel.activeRow == nil)
        #expect(viewModel.headline == "Next: Dhuhr in 10m")
    }

    @Test("A countdown of over an hour is shown in hours and minutes")
    func headlineUsesHoursAndMinutesForLongerCountdowns() throws {
        // 8:00 a.m. Toronto: after sunrise, well over an hour before Dhuhr (13:05).
        let now = ISO8601DateFormatter().date(from: "2026-09-19T12:00:00Z")!
        let (viewModel, _, _) = try makeViewModel(now: now)
        viewModel.refresh()

        #expect(viewModel.headline == "Next: Dhuhr in 5h 5m")
    }

    @Test("A recorded on-time check-in shows as checked in, not just open")
    func recordedOnTimeCheckIn() throws {
        let now = ISO8601DateFormatter().date(from: "2026-09-19T09:40:00Z")!
        let (viewModel, historyStore, timeline) = try makeViewModel(now: now)
        let fajr = timeline.slots(onDayOf: now).first { $0.prayer == .fajr }!
        try historyStore.recordCheckIn(
            for: fajr, isLate: false, checkedInAt: now, frontImageData: nil, rearImageData: nil,
            expiresAt: now.addingTimeInterval(3600)
        )

        viewModel.refresh()

        let fajrRow = try #require(viewModel.rows.first { $0.slot.prayer == .fajr })
        #expect(fajrRow.status == .checkedInOnTime)
        #expect(viewModel.activeRow?.status == .checkedInOnTime)
    }

    @Test("A late check-in still counts and says so, without ever calling it a failure")
    func recordedLateCheckIn() throws {
        // 2:00 p.m. Toronto: inside Dhuhr's window, past its 30-minute on-time cutoff.
        let now = ISO8601DateFormatter().date(from: "2026-09-19T18:00:00Z")!
        let (viewModel, historyStore, timeline) = try makeViewModel(now: now)
        let dhuhr = timeline.slots(onDayOf: now).first { $0.prayer == .dhuhr }!
        try historyStore.recordCheckIn(
            for: dhuhr, isLate: true, checkedInAt: now, frontImageData: nil, rearImageData: nil,
            expiresAt: now.addingTimeInterval(3600)
        )

        viewModel.refresh()

        let dhuhrRow = try #require(viewModel.rows.first { $0.slot.prayer == .dhuhr })
        #expect(dhuhrRow.status == .checkedInLate)
        #expect(dhuhrRow.status.label == "Checked in late — still counts")
        #expect(!dhuhrRow.status.label.lowercased().contains("fail"))
        #expect(!dhuhrRow.status.label.lowercased().contains("missed"))
    }

    @Test("A window that closed with no record shows a neutral 'no check-in', never styled as a failure")
    func closedWindowWithNoRecordIsNeutral() throws {
        // 7:00 a.m. Toronto: after sunrise, Fajr's window is closed.
        let now = ISO8601DateFormatter().date(from: "2026-09-19T11:00:00Z")!
        let (viewModel, _, _) = try makeViewModel(now: now)
        viewModel.refresh()

        let fajrRow = try #require(viewModel.rows.first { $0.slot.prayer == .fajr })
        #expect(fajrRow.status == .missed)
        #expect(fajrRow.status.label == "No check-in")
    }

    @Test("A pause freezes the affected slot instead of marking it missed (RDP-3)")
    func pausedSlotIsNeitherCountedNorMissed() throws {
        // 2:00 p.m. Toronto: inside Dhuhr's window.
        let now = ISO8601DateFormatter().date(from: "2026-09-19T18:00:00Z")!
        let (viewModel, historyStore, _) = try makeViewModel(now: now)
        try historyStore.recordPause(startedAt: now.addingTimeInterval(-3600), endsAt: nil)

        viewModel.refresh()

        let dhuhrRow = try #require(viewModel.rows.first { $0.slot.prayer == .dhuhr })
        #expect(dhuhrRow.status == .paused)
        #expect(viewModel.activeRow?.status == .paused)
    }

    @Test("A slot that began before the user completed onboarding is not tracked, not missed")
    func slotBeforeOnboardingIsNotTracked() throws {
        // Onboarded at 1 p.m. Toronto, today -- after Fajr's window already closed.
        let onboardedAt = ISO8601DateFormatter().date(from: "2026-09-19T17:00:00Z")!
        let now = onboardedAt.addingTimeInterval(3600)
        let (viewModel, _, _) = try makeViewModel(now: now, onboardingCompletedAt: onboardedAt)

        viewModel.refresh()

        let fajrRow = try #require(viewModel.rows.first { $0.slot.prayer == .fajr })
        #expect(fajrRow.status == .notTracked)
    }

    @Test("Marking a closed, unrecorded window as prayed updates its row and counts toward the streak (RUKI-026)")
    func markingAsPrayedUpdatesRowStatus() throws {
        // 7 a.m. Toronto: Fajr's window is closed with no check-in.
        let now = ISO8601DateFormatter().date(from: "2026-09-19T11:00:00Z")!
        let (viewModel, _, _) = try makeViewModel(now: now)
        viewModel.refresh()
        let fajrRow = try #require(viewModel.rows.first { $0.slot.prayer == .fajr })
        #expect(fajrRow.status == .missed)

        viewModel.mark(fajrRow, as: .prayed)

        let updated = try #require(viewModel.rows.first { $0.slot.prayer == .fajr })
        #expect(updated.status == .markedPrayed)
    }

    @Test("Marking a closed, unrecorded window as not prayed keeps it neutral, never a re-flagged failure")
    func markingAsNotPrayedStaysNeutral() throws {
        let now = ISO8601DateFormatter().date(from: "2026-09-19T11:00:00Z")!
        let (viewModel, _, _) = try makeViewModel(now: now)
        viewModel.refresh()
        let fajrRow = try #require(viewModel.rows.first { $0.slot.prayer == .fajr })

        viewModel.mark(fajrRow, as: .missed)

        let updated = try #require(viewModel.rows.first { $0.slot.prayer == .fajr })
        #expect(updated.status == .missed)
        #expect(updated.status.label == "No check-in")
    }

    @Test("Pausing freezes the currently-open slot instead of leaving it to resolve as missed (RUKI-034)")
    func pausingFreezesTheOpenSlot() throws {
        // Inside Dhuhr's window.
        let now = ISO8601DateFormatter().date(from: "2026-09-19T18:00:00Z")!
        let (viewModel, historyStore, _) = try makeViewModel(now: now)
        viewModel.refresh()

        viewModel.pause(for: .untilResumed)

        let dhuhrRow = try #require(viewModel.rows.first { $0.slot.prayer == .dhuhr })
        #expect(dhuhrRow.status == .paused)
        let pauses = try historyStore.pauseSnapshots()
        #expect(pauses.count == 1)
        #expect(pauses.first?.startedAt == now)
        #expect(pauses.first?.endsAt == nil)
    }

    @Test("Builds a check-in view model honouring the Space Only default and expiring at the next slot (RUKI-020)")
    func makeCheckInViewModelUsesSettingsAndNextSlot() async throws {
        // 5:30 a.m. Toronto: Fajr open, on time.
        let now = ISO8601DateFormatter().date(from: "2026-09-19T09:30:00Z")!
        let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard)
        let userSettings = UserSettings(defaults: freshDefaults())
        userSettings.onboardingCompletedAt = now.addingTimeInterval(-86_400)
        userSettings.spaceOnlyDefault = true
        let historyStore = HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        let viewModel = TodayViewModel(
            timeline: timeline, clock: FixedClock(date: now), userSettings: userSettings, historyStore: historyStore
        )
        viewModel.refresh()
        let fajrRow = try #require(viewModel.rows.first { $0.slot.prayer == .fajr })
        let recorder = CaptureCallRecorder()

        let checkInViewModel = viewModel.makeCheckInViewModel(
            for: fajrRow, cameraProvider: RecordingCameraProvider(recorder: recorder)
        )
        #expect(checkInViewModel.isLate == false)

        await checkInViewModel.affirmPrayed()
        checkInViewModel.post()

        #expect(await recorder.lastMode == .spaceOnly)
        let record = try #require(try historyStore.checkInSnapshots().first)
        #expect(record.slotID == fajrRow.slot.id)
    }

    @Test("A fixed-length pause records the right end date")
    func fixedLengthPauseRecordsEndDate() throws {
        let now = ISO8601DateFormatter().date(from: "2026-09-19T18:00:00Z")!
        let (viewModel, historyStore, _) = try makeViewModel(now: now)

        viewModel.pause(for: .threeDays)

        let pauses = try historyStore.pauseSnapshots()
        #expect(pauses.count == 1)
        #expect(pauses.first?.startedAt == now)
        #expect(pauses.first?.endsAt == now.addingTimeInterval(3 * 24 * 60 * 60))
    }
}
