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

        await viewModel.takePhoto()

        #expect(await recorder.callCount == 1)
    }

    @Test("Affirming moves to review with the captured photo on success")
    func affirmingMovesToReviewOnSuccess() async throws {
        let photo = CapturedPhoto(frontImageData: Data([0x9]), rearImageData: Data([0xA]))
        let viewModel = try makeViewModel(
            cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder(), photoToReturn: photo)
        )

        await viewModel.affirmPrayed()

        await viewModel.takePhoto()

        #expect(viewModel.state == .review(photo))
    }

    @Test("Affirming starts the camera but does not fire the shutter -- the person frames the shot and presses it")
    func affirmDoesNotFireTheShutter() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))

        await viewModel.affirmPrayed()

        #expect(viewModel.state == .framing)
        #expect(await recorder.callCount == 0, "the shutter must wait for the person")

        await viewModel.takePhoto()

        #expect(await recorder.callCount == 1)
        if case .review = viewModel.state {} else { Issue.record("Expected .review after the shutter, got \(viewModel.state)") }
    }

    @Test("The shutter does nothing unless the camera is framing")
    func shutterOnlyWorksWhileFraming() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))

        await viewModel.takePhoto()   // still on the affirm step

        #expect(viewModel.state == .affirm)
        #expect(await recorder.callCount == 0)
    }

    @Test("Retake goes back to framing for one more shot and is then capped (RUKI-020)")
    func retakeReturnsToFramingOnceOnly() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))
        await viewModel.affirmPrayed()
        await viewModel.takePhoto()

        await viewModel.retake()
        #expect(viewModel.state == .framing)
        #expect(viewModel.retakeCount == 1)
        #expect(viewModel.canRetake == false)

        await viewModel.takePhoto()
        await viewModel.retake()   // a second retake is refused, not merely discouraged

        #expect(viewModel.retakeCount == 1)
        if case .review = viewModel.state {} else { Issue.record("Second retake must be a no-op, got \(viewModel.state)") }
        #expect(await recorder.callCount == 2)
    }

    @Test("Tapping \"I've prayed\" again while already framing does not restart anything")
    func repeatedAffirmIsIgnored() async throws {
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder()))
        await viewModel.affirmPrayed()

        await viewModel.affirmPrayed()

        #expect(viewModel.state == .framing)
    }

    @Test("From the notification to a saved check-in takes three deliberate taps: I've prayed, the shutter, Post (RUKI-019)")
    func checkInNeedsOnlyThreeTaps() async throws {
        let store = try HistoryStore(modelContainer: RukiModelContainer.make(inMemory: true))
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder()), historyStore: store)

        await viewModel.affirmPrayed()   // tap 1
        await viewModel.takePhoto()      // tap 2
        viewModel.post()                 // tap 3

        #expect(viewModel.state == .posted)
        #expect(try store.checkInSnapshots().count == 1)
    }

    @Test("A capture failure moves to .failed, never silently to .review")
    func captureFailureMovesToFailed() async throws {
        let viewModel = try makeViewModel(
            cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder(), photoToReturn: nil)
        )

        await viewModel.affirmPrayed()

        await viewModel.takePhoto()

        #expect(viewModel.state == .failed)
    }

    @Test("Retake calls the camera again and counts the retake")
    func retakeCallsCameraAgain() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))
        await viewModel.affirmPrayed()
        await viewModel.takePhoto()

        await viewModel.retake()

        await viewModel.takePhoto()

        #expect(await recorder.callCount == 2)
        #expect(viewModel.retakeCount == 1)
        if case .review = viewModel.state {} else {
            Issue.record("Expected .review after a successful retake, got \(viewModel.state)")
        }
    }

    @Test("Retake is hard-capped at one -- a second attempt is a no-op (RUKI-020)")
    func secondRetakeIsANoOp() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))
        await viewModel.affirmPrayed()
        await viewModel.takePhoto()
        await viewModel.retake()
        await viewModel.takePhoto()
        #expect(viewModel.canRetake == false)

        await viewModel.retake()

        await viewModel.takePhoto()

        #expect(await recorder.callCount == 2, "the second retake must not call the camera again")
        #expect(viewModel.retakeCount == 1)
    }

    @Test("canRetake is true until the cap is reached")
    func canRetakeReflectsTheCap() async throws {
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder()))
        await viewModel.affirmPrayed()
        await viewModel.takePhoto()
        #expect(viewModel.canRetake == true)

        await viewModel.retake()

        await viewModel.takePhoto()

        #expect(viewModel.canRetake == false)
    }

    @Test("Denied camera authorization moves to .failed without starting a session")
    func deniedAuthorizationMovesToFailed() async throws {
        let viewModel = try makeViewModel(cameraProvider: FakeCameraProvider(authorized: false))

        await viewModel.affirmPrayed()

        await viewModel.takePhoto()

        #expect(viewModel.state == .failed)
    }

    @Test("Retaking before a photo exists is a no-op")
    func retakeBeforeReviewIsNoOp() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))

        await viewModel.retake()

        await viewModel.takePhoto()

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
        await viewModel.takePhoto()

        viewModel.post()

        #expect(viewModel.state == .posted)
        let snapshots = try historyStore.checkInSnapshots()
        #expect(snapshots == [CheckInSnapshot(slotID: viewModel.slot.id, isLate: true)])
    }

    @Test("RUKI-027: posting after a retake stores the retake count")
    func postingAfterRetakeStoresRetakeCount() async throws {
        let container = try RukiModelContainer.make(inMemory: true)
        let historyStore = HistoryStore(modelContainer: container)
        let viewModel = try makeViewModel(
            cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder()),
            historyStore: historyStore
        )
        await viewModel.affirmPrayed()
        await viewModel.takePhoto()
        await viewModel.retake()
        await viewModel.takePhoto()

        viewModel.post()

        let context = ModelContext(container)
        let record = try #require(try context.fetch(FetchDescriptor<CheckInRecord>()).first)
        #expect(record.retakeCount == 1)
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
        await viewModel.takePhoto()
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
        await viewModel.takePhoto()

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

    @Test("RUKI-022: toggling Space Only before affirming changes the mode capturePhoto is called with")
    func togglingSpaceOnlyChangesCaptureMode() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))
        #expect(viewModel.isSpaceOnly == false)

        viewModel.toggleSpaceOnly()
        #expect(viewModel.isSpaceOnly == true)
        await viewModel.affirmPrayed()
        await viewModel.takePhoto()

        #expect(await recorder.lastMode == .spaceOnly)
    }

    @Test("RUKI-022: toggling twice returns to the original mode")
    func togglingSpaceOnlyTwiceReturnsToOriginal() throws {
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: CaptureCallRecorder()))

        viewModel.toggleSpaceOnly()
        viewModel.toggleSpaceOnly()

        #expect(viewModel.isSpaceOnly == false)
    }

    @Test("RUKI-022: the toggle is a no-op once capture has already started")
    func toggleIsNoOpAfterCaptureStarts() async throws {
        let recorder = CaptureCallRecorder()
        let viewModel = try makeViewModel(cameraProvider: RecordingCameraProvider(recorder: recorder))
        await viewModel.affirmPrayed()
        await viewModel.takePhoto()

        viewModel.toggleSpaceOnly()

        #expect(viewModel.isSpaceOnly == false)
        #expect(await recorder.lastMode == .dual)
    }
}
