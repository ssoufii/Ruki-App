import Foundation
import Observation

/// RUKI-019: the check-in state machine — affirm → camera → review → post.
///
/// `affirmPrayed()` is the *only* path that ever calls `cameraProvider`
/// (RDP-4: the camera must never be reachable before the user affirms
/// they've finished praying). Posting is immediate and final (PRD §7.4,
/// "no draft state") — there's nothing to save and resume, only `.affirm`,
/// `.capturing`, `.review`, `.posted`, and `.failed` to be in.
@MainActor
@Observable
final class CheckInViewModel {
    enum State: Sendable, Equatable {
        case affirm
        case capturing
        case review(CapturedPhoto)
        case posted
        case failed
    }

    let slot: PrayerSlot
    let isLate: Bool

    private let captureMode: CaptureMode
    private let expiresAt: Date
    private let cameraProvider: any CameraProviding
    private let clock: any ClockProviding
    private let historyStore: HistoryStore

    private(set) var state: State = .affirm
    private(set) var retakeCount = 0

    /// - Parameters:
    ///   - isLate: decided by the caller from `PrayerTimeline.phase`, not
    ///     recomputed here — this type has no notion of "now" beyond `clock`.
    ///   - expiresAt: the next prayer's start (D26/D37); when the photo gets purged.
    init(
        slot: PrayerSlot,
        isLate: Bool,
        captureMode: CaptureMode,
        expiresAt: Date,
        cameraProvider: any CameraProviding,
        clock: any ClockProviding,
        historyStore: HistoryStore
    ) {
        self.slot = slot
        self.isLate = isLate
        self.captureMode = captureMode
        self.expiresAt = expiresAt
        self.cameraProvider = cameraProvider
        self.clock = clock
        self.historyStore = historyStore
    }

    var affirmPrompt: String {
        String(localized: "Have you prayed \(slot.prayer.displayName)?")
    }

    /// Tone rule (CLAUDE.md): late still counts, and says so warmly.
    var postedMessage: String {
        isLate
            ? String(localized: "Checked in late — still counts.")
            : String(localized: "Checked in.")
    }

    func affirmPrayed() async {
        state = .capturing
        await capture()
    }

    func retake() async {
        guard case .review = state else { return }
        retakeCount += 1
        state = .capturing
        await capture()
    }

    /// Records the check-in and moves straight to `.posted` — no draft to
    /// discard, nothing left behind if the user had backed out first.
    func post() {
        guard case .review(let photo) = state else { return }
        do {
            try historyStore.recordCheckIn(
                for: slot,
                isLate: isLate,
                checkedInAt: clock.now(),
                frontImageData: photo.frontImageData,
                rearImageData: photo.rearImageData,
                expiresAt: expiresAt
            )
            state = .posted
        } catch {
            state = .failed
        }
    }

    private func capture() async {
        do {
            let photo = try await cameraProvider.capturePhoto(mode: captureMode)
            state = .review(photo)
        } catch {
            state = .failed
        }
    }
}
