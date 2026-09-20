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
    /// `.capturing` step. Must only be called after `startSession()`. Plain
    /// `nonisolated`, not `@MainActor`: it only builds a value type (the
    /// `UIViewRepresentable` doesn't touch UIKit until SwiftUI calls
    /// `makeUIView` on the main thread itself), and conformers that hold
    /// their session behind actor isolation would otherwise have to cross a
    /// *different* global actor to build it.
    nonisolated func makePreviewView() -> AnyView

    func capturePhoto(mode: CaptureMode) async throws -> CapturedPhoto
}
