import Foundation
@testable import Ruki

/// Counts `capturePhoto` calls, for the RUKI-019 test that the camera is
/// never reached before the user affirms (RDP-4). An `actor` rather than a
/// plain mutable class, so the counter stays safe to increment from
/// whatever context `capturePhoto` runs on.
actor CaptureCallRecorder {
    private(set) var callCount = 0

    func recordCall() {
        callCount += 1
    }
}

struct RecordingCameraProvider: CameraProviding {
    let recorder: CaptureCallRecorder
    var photoToReturn: CapturedPhoto? = CapturedPhoto(
        frontImageData: Data([0x01]),
        rearImageData: Data([0x02])
    )

    struct CaptureFailure: Error, Sendable {}

    nonisolated func isDualCameraSupported() -> Bool { true }

    func capturePhoto(mode: CaptureMode) async throws -> CapturedPhoto {
        await recorder.recordCall()
        guard let photoToReturn else { throw CaptureFailure() }
        return photoToReturn
    }
}
