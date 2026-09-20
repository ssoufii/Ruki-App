import Foundation
import SwiftData
import Testing
@testable import Ruki

@MainActor
@Suite("CheckInViewModel")
struct CheckInViewModelTests {
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T09:40:00Z")!

    private func makeSlot(prayer: Prayer = .fajr) -> PrayerSlot {
        let window = PrayerWindow(
            prayer: prayer, madhab: .standard, start: referenceDate,
            checkInWindowEnd: referenceDate.addingTimeInterval(1800), end: referenceDate.addingTimeInterval(3600)
        )
        return PrayerSlot(window: window)
    }

    private func makeViewModel(
        isLate: Bool = false,
        cameraProvider: any CameraProviding,
        historyStore: HistoryStore? = nil
    ) throws -> CheckInViewModel {
        let slot = makeSlot()
        let store = try historyStore ?? HistoryStore(modelContainer: RukiModelContainer.make(inMemory: true))
        return CheckInViewModel(
            slot: slot,
            isLate: isLate,
            captureMode: .dual,
            expiresAt: slot.window.end,
            cameraProvider: cameraProvider,
            clock: FixedClock(date: referenceDate),
            historyStore: store
        )
    }

    @Test("The camera is never touched before the user affirms they've prayed (RDP-4)")
    func cameraUnreachableBeforeAffirming() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))

        #expect(viewModel.state == .affirm)
        #expect(await recorder.callCount == 0)

        await viewModel.affirmPrayed()

        #expect(await recorder.callCount == 1)
    }

    @Test("Affirming moves to review with the captured photo on success")
    func affirmingMovesToReviewOnSuccess() async throws {
        let photo = CapturedPhoto(frontImageData: Data([0x9]), rearImageData: Data([0xA]))
        let viewModel = try makeViewModel(
            cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder(), photoToReturn: photo)
        )

        await viewModel.affirmPrayed()

        #expect(viewModel.state == .review(photo))
    }

    @Test("A capture failure moves to .failed, never silently to .review")
    func captureFailureMovesToFailed() async throws {
        let viewModel = try makeViewModel(
            cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder(), photoToReturn: nil)
        )

        await viewModel.affirmPrayed()

        #expect(viewModel.state == .failed)
    }

    @Test("Retake calls the camera again and counts the retake")
    func retakeCallsCameraAgain() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))
        await viewModel.affirmPrayed()

        await viewModel.retake()

        #expect(await recorder.callCount == 2)
        #expect(viewModel.retakeCount == 1)
        if case .review = viewModel.state {} else {
            Issue.record("Expected .review after a successful retake, got \(viewModel.state)")
        }
    }

    @Test("Retaking before a photo exists is a no-op")
    func retakeBeforeReviewIsNoOp() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))

        await viewModel.retake()

        #expect(await recorder.callCount == 0)
        #expect(viewModel.retakeCount == 0)
        #expect(viewModel.state == .affirm)
    }

    @Test("Posting records the check-in and moves to .posted")
    func postingRecordsCheckIn() async throws {
        let historyStore = HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        let photo = CapturedPhoto(frontImageData: Data([0x1]), rearImageData: Data([0x2]))
        let viewModel = try makeViewModel(
            isLate: true,
            cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder(), photoToReturn: photo),
            historyStore: historyStore
        )
        await viewModel.affirmPrayed()

        viewModel.post()

        #expect(viewModel.state == .posted)
        let snapshots = try historyStore.checkInSnapshots()
        #expect(snapshots == [CheckInSnapshot(slotID: viewModel.slot.id, isLate: true)])
    }

    @Test("Posting sanitizes the caption (trimmed, capped at 80) before it's stored")
    func postingSanitizesCaption() async throws {
        let container = try RukiModelContainer.make(inMemory: true)
        let historyStore = HistoryStore(modelContainer: container)
        let viewModel = try makeViewModel(
            cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder()),
            historyStore: historyStore
        )
        await viewModel.affirmPrayed()
        viewModel.caption = "  \n Alhamdulillah \n  "

        viewModel.post()

        let context = ModelContext(container)
        let record = try #require(try context.fetch(FetchDescriptor<CheckInRecord>()).first)
        #expect(record.caption == "Alhamdulillah")
    }

    @Test("An empty caption is stored as nil, not an empty string")
    func emptyCaptionStoresAsNil() async throws {
        let container = try RukiModelContainer.make(inMemory: true)
        let historyStore = HistoryStore(modelContainer: container)
        let viewModel = try makeViewModel(
            cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder()),
            historyStore: historyStore
        )
        await viewModel.affirmPrayed()

        viewModel.post()

        let context = ModelContext(container)
        let record = try #require(try context.fetch(FetchDescriptor<CheckInRecord>()).first)
        #expect(record.caption == nil)
    }

    @Test("Posting before a photo exists is a no-op -- nothing is recorded")
    func postingBeforeReviewIsNoOp() async throws {
        let historyStore = HistoryStore(modelContainer: try RukiModelContainer.make(inMemory: true))
        let viewModel = try makeViewModel(
            cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder()),
            historyStore: historyStore
        )

        viewModel.post()

        #expect(viewModel.state == .affirm)
        #expect(try historyStore.checkInSnapshots().isEmpty)
    }

    @Test("Late check-ins get warm, forward-looking copy -- never a failure word")
    func lateCopyStaysWarm() throws {
        let viewModel = try makeViewModel(
            isLate: true, cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder())
        )
        #expect(viewModel.postedMessage == "Checked in late — still counts.")
        #expect(!viewModel.postedMessage.lowercased().contains("fail"))
        #expect(!viewModel.postedMessage.lowercased().contains("missed"))
    }

    @Test("The affirm prompt names the specific prayer")
    func affirmPromptNamesThePrayer() throws {
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder()))
        #expect(viewModel.affirmPrompt == "Have you prayed Fajr?")
    }
}
