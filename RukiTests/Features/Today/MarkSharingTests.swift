import Foundation
import Testing
@testable import Ruki

@MainActor
private final class SpyPublisher: CheckInPublishing {
    private(set) var uploads: [CheckInUpload] = []
    func publish(_ upload: CheckInUpload) { uploads.append(upload) }
}

/// D49 / RDP-2: "I prayed" reaches the circle as a post with no photo; "I didn't" never
/// produces a network event.
@MainActor
@Suite("Marks and the circle (D49)")
struct MarkSharingTests {
    private let now = ISO8601DateFormatter().date(from: "2026-09-19T15:00:00-04:00")!   // Dhuhr's window has closed by Asr

    private func viewModelWithClosedFajr() throws -> (TodayViewModel, TodayViewModel.Row) {
        let settings = UserSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        settings.onboardingCompletedAt = now.addingTimeInterval(-12 * 3600)
        let viewModel = TodayViewModel(
            timeline: PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard),
            clock: FixedClock(date: now),
            userSettings: settings,
            historyStore: HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        )
        viewModel.refresh()
        let row = try #require(viewModel.rows.first { $0.status == .missed }, "expected a closed, unrecorded prayer")
        return (viewModel, row)
    }

    @Test("\"I prayed\" is shared as a photo-less post that lives until the next prayer begins")
    func prayedIsShared() throws {
        let (viewModel, row) = try viewModelWithClosedFajr()
        let spy = SpyPublisher()
        viewModel.mark(row, as: .prayed, publisher: spy)

        let upload = try #require(spy.uploads.first)
        #expect(spy.uploads.count == 1)
        #expect(upload.slotID == row.slot.id && upload.prayer == row.slot.prayer)
        #expect(upload.rearPhoto == nil && upload.frontPhoto == nil && upload.caption == nil)
        #expect(upload.expiresAt > now, "a post already expired when created would never be seen")
    }

    @Test("\"I didn't\" never produces a network event")
    func missedIsNeverShared() throws {
        let (viewModel, row) = try viewModelWithClosedFajr()
        let spy = SpyPublisher()
        viewModel.mark(row, as: .missed, publisher: spy)
        #expect(spy.uploads.isEmpty)
    }

    @Test("Signed out (no publisher), a mark is simply saved on the device")
    func markWithoutAccountStaysLocal() throws {
        let (viewModel, row) = try viewModelWithClosedFajr()
        viewModel.mark(row, as: .prayed)
        #expect(viewModel.rows.first { $0.id == row.id }?.status == .markedPrayed)
    }
}
