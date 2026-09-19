import Foundation
@testable import Ruki

/// Camera fake — returns fixed, tiny placeholder image data rather than
/// touching `AVFoundation`, so capture-flow logic (Epic 05) can be tested
/// on any host including CI, which has no camera.
struct FakeCameraProvider: CameraProviding {
    struct CaptureFailure: Error, Sendable {}

    var dualCameraSupported = true
    var photoToReturn: CapturedPhoto? = CapturedPhoto(
        frontImageData: Data([0x01]),
        rearImageData: Data([0x02])
    )

    nonisolated func isDualCameraSupported() -> Bool {
        dualCameraSupported
    }

    func capturePhoto(mode: CaptureMode) async throws -> CapturedPhoto {
        guard let photoToReturn else { throw CaptureFailure() }
        return photoToReturn
    }
}
