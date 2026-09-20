import Foundation
import SwiftUI

/// Which cards a capture produces. Space Only uses the rear camera alone
/// (PRD §7.4) for users who don't want to appear in frame.
enum CaptureMode: Sendable, Equatable {
    case dual
    case spaceOnly
}

/// Result of a single capture. `frontImageData` is `nil` for `.spaceOnly`
/// captures and on sequential-fallback hardware that only shot the rear frame.
struct CapturedPhoto: Sendable, Equatable {
    let frontImageData: Data?
    let rearImageData: Data
}

/// Wraps `AVFoundation` so the check-in capture flow (Epic 05) can be built
/// and tested against a fake before any real camera code exists.
protocol CameraProviding: Sendable {
    /// Whether this hardware can in principle run a simultaneous front+rear
    /// session (`AVCaptureMultiCamSession.isMultiCamSupported`, A12 Bionic+).
    /// A device capability check, not a guarantee `startSession()` will
    /// actually configure multi-cam successfully — `capturePhoto` falls back
    /// to sequential front-then-rear automatically if that configuration
    /// fails at runtime (RUKI-021), independent of what this returns.
    nonisolated func isDualCameraSupported() -> Bool

    /// Requests camera access if not yet determined; returns the current
    /// authorization state. Never called before the user affirms they've
    /// prayed (RDP-4) — `CheckInViewModel.affirmPrayed()` is the only caller.
    func requestAuthorization() async -> Bool

    /// Configures and starts the capture session. Safe to call once per
    /// check-in; a second call while already running is a no-op.
    func startSession() async throws

    /// Stops the session. Called when the check-in flow ends, one way or
    /// another, so the camera indicator doesn't stay lit.
    func stopSession() async

    /// A live view of whatever the session currently sees, for the
    /// `.capturing` step. Must only be called after `startSession()`.
    /// `@MainActor`, not `nonisolated`: its only real caller,
    /// `CheckInViewModel.previewView`, is itself `@MainActor` (SwiftUI never
    /// builds a view off the main actor), and `CameraPreviewRepresentable`
    /// storing a plain `AVCaptureSession` property needs its whole
    /// `UIViewRepresentable` conformance — including its init — isolated
    /// the ordinary way. An earlier `nonisolated` version needed
    /// `nonisolated(unsafe)` on that stored property to compile, which
    /// Swift 6 (Xcode 16.4) still rejected at the property's assignment
    /// in `init` (`main actor-isolated property 'session' can not be
    /// mutated from a nonisolated context`) even with the attribute
    /// present — going through the main actor like every other SwiftUI
    /// view removes the need for that escape hatch entirely.
    @MainActor func makePreviewView() -> AnyView

    func capturePhoto(mode: CaptureMode) async throws -> CapturedPhoto
}
