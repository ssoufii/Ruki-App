import Foundation

/// Which cards a capture produces. Space Only uses the rear camera alone
/// (PRD §7.4) for users who don't want to appear in frame.
enum CaptureMode: Sendable {
    case dual
    case spaceOnly
}

/// Result of a single capture. `frontImageData` is `nil` for `.spaceOnly`
/// captures and on sequential-fallback hardware that only shot the rear frame.
struct CapturedPhoto: Sendable {
    let frontImageData: Data?
    let rearImageData: Data
}

/// Wraps `AVFoundation` so the check-in capture flow (Epic 05) can be built
/// and tested against a fake before any real camera code exists.
protocol CameraProviding: Sendable {
    /// Whether this device supports `AVCaptureMultiCamSession` (A12 Bionic+).
    /// Devices that don't must fall back to sequential front-then-rear capture.
    nonisolated func isDualCameraSupported() -> Bool

    func capturePhoto(mode: CaptureMode) async throws -> CapturedPhoto
}
