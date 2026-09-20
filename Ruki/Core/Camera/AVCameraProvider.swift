import AVFoundation
import Foundation
import SwiftUI

/// Real camera capture. Never used on the Simulator (no camera hardware at
/// all) — `AppEnvironment` selects `PlaceholderCameraProvider` there via
/// `#if targetEnvironment(simulator)`.
///
/// A plain class, not an `actor`: three attempts at an actor-isolated
/// version fought the Swift 6 type checker over `nonisolated(unsafe)`
/// session properties crossing into `CameraPreviewRepresentable`'s
/// `@MainActor`-inferred `UIViewRepresentable` isolation, and never
/// resolved (full diagnosis on issue #20). This is the traditional,
/// pre-actor `AVFoundation` pattern Apple's own AVCam/AVMultiCamPiP samples
/// use: a private serial `sessionQueue` serializes every session
/// configuration and capture call, `@unchecked Sendable` matches this
/// codebase's own precedent for a type holding only Apple capture-session
/// state (`UserNotificationScheduler`), and nothing here needs to cross a
/// *named* isolation domain, sidestepping the actor/`nonisolated(unsafe)`/
/// `@MainActor` conflict entirely.
final class AVCameraProvider: NSObject, CameraProviding, @unchecked Sendable {
    enum CameraError: Error {
        case configurationFailed
        case notConfigured
        case noImageData
    }

    private let sessionQueue = DispatchQueue(label: "com.salimsoufi.Ruki.cameraSession")

    /// Read from `makePreviewView()` without hopping onto `sessionQueue` —
    /// safe in practice: `AVCaptureSession` is documented to tolerate being
    /// driven from a session queue while a preview layer elsewhere reads it
    /// live, which is exactly this split, and `multiCamConfigured` only
    /// ever flips once, during `startSession()`, before any preview view is
    /// requested.
    private let multiCamSession = AVCaptureMultiCamSession()
    private let singleCamSession = AVCaptureSession()
    private var multiCamConfigured = false

    private var singleCamOutput: AVCapturePhotoOutput?
    private var multiCamFrontOutput: AVCapturePhotoOutput?
    private var multiCamRearOutput: AVCapturePhotoOutput?
    private var sessionStarted = false
    private var activeDelegates: [UUID: PhotoCaptureDelegate] = [:]

    nonisolated func isDualCameraSupported() -> Bool {
        AVCaptureMultiCamSession.isMultiCamSupported
    }

    func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func startSession() async throws {
        try await performOnSessionQueue {
            guard !self.sessionStarted else { return }

            if AVCaptureMultiCamSession.isMultiCamSupported, self.configureMultiCamSession() {
                self.multiCamConfigured = true
                self.multiCamSession.startRunning()
            } else {
                self.multiCamConfigured = false
                try self.configureSingleCamSession(position: .front)
                self.singleCamSession.startRunning()
            }
            self.sessionStarted = true
        }
    }

    func stopSession() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if self.multiCamSession.isRunning { self.multiCamSession.stopRunning() }
                if self.singleCamSession.isRunning { self.singleCamSession.stopRunning() }
                self.sessionStarted = false
                continuation.resume()
            }
        }
    }

    /// Reads `multiCamConfigured`/the session references directly, off
    /// `sessionQueue` — see the type's own doc comment for why that's safe
    /// here. `@MainActor` (see the protocol requirement's doc comment for
    /// why): this method's only caller is already on the main actor, so
    /// there's no isolation to cross.
    @MainActor func makePreviewView() -> AnyView {
        let session: AVCaptureSession = multiCamConfigured ? multiCamSession : singleCamSession
        return AnyView(CameraPreviewRepresentable(session: session))
    }

    func capturePhoto(mode: CaptureMode) async throws -> CapturedPhoto {
        switch CameraCaptureStrategyResolver.resolve(mode: mode, dualCameraSupported: multiCamConfigured) {
        case .rearOnly:
            // Space Only: use whichever session `startSession()` actually
            // configured — the multi-cam session's own rear output if that
            // succeeded, otherwise the single-camera session. Never starts a
            // session neither branch configured.
            let rear = multiCamConfigured
                ? try await capture(.multiCamRear)
                : try await captureSingleCam(position: .back)
            return CapturedPhoto(frontImageData: nil, rearImageData: rear)
        case .simultaneousDualCamera:
            async let front = capture(.multiCamFront)
            async let rear = capture(.multiCamRear)
            return try await CapturedPhoto(frontImageData: front, rearImageData: rear)
        case .sequentialFrontThenRear:
            let front = try await captureSingleCam(position: .front)
            let rear = try await captureSingleCam(position: .back)
            return CapturedPhoto(frontImageData: front, rearImageData: rear)
        }
    }

    // MARK: Multi-cam configuration

    /// Follows Apple's documented multi-cam wiring: inputs and outputs are
    /// added with no default connections, then joined explicitly per camera
    /// so each `AVCapturePhotoOutput` only ever sees its own camera's frames.
    /// Any failure along the way returns `false` rather than throwing, so
    /// `startSession()` falls back to the single-camera path automatically
    /// (RUKI-021) instead of the check-in flow failing outright.
    ///
    /// Only ever called from a block already running on `sessionQueue`.
    private func configureMultiCamSession() -> Bool {
        multiCamSession.beginConfiguration()
        defer { multiCamSession.commitConfiguration() }

        guard
            let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let rearDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let frontInput = try? AVCaptureDeviceInput(device: frontDevice),
            let rearInput = try? AVCaptureDeviceInput(device: rearDevice),
            multiCamSession.canAddInput(frontInput),
            multiCamSession.canAddInput(rearInput)
        else { return false }

        multiCamSession.addInputWithNoConnections(frontInput)
        multiCamSession.addInputWithNoConnections(rearInput)

        let frontOutput = AVCapturePhotoOutput()
        let rearOutput = AVCapturePhotoOutput()
        guard multiCamSession.canAddOutput(frontOutput), multiCamSession.canAddOutput(rearOutput) else {
            return false
        }
        multiCamSession.addOutputWithNoConnections(frontOutput)
        multiCamSession.addOutputWithNoConnections(rearOutput)

        guard
            let frontPort = frontInput.ports(
                for: .video, sourceDeviceType: frontDevice.deviceType, sourceDevicePosition: .front
            ).first,
            let rearPort = rearInput.ports(
                for: .video, sourceDeviceType: rearDevice.deviceType, sourceDevicePosition: .back
            ).first
        else { return false }

        let frontConnection = AVCaptureConnection(inputPorts: [frontPort], output: frontOutput)
        let rearConnection = AVCaptureConnection(inputPorts: [rearPort], output: rearOutput)
        guard multiCamSession.canAddConnection(frontConnection), multiCamSession.canAddConnection(rearConnection) else {
            return false
        }
        multiCamSession.addConnection(frontConnection)
        multiCamSession.addConnection(rearConnection)

        multiCamFrontOutput = frontOutput
        multiCamRearOutput = rearOutput
        return true
    }

    // MARK: Single-camera (Space Only, and sequential fallback)

    /// One `AVCaptureSession` whose input is swapped between shots — used
    /// both for Space Only (rear only, never swapped) and the sequential
    /// fallback (front, then rear, on hardware without multi-cam, RUKI-021).
    /// Only ever called from a block already running on `sessionQueue`.
    private func configureSingleCamSession(position: AVCaptureDevice.Position) throws {
        singleCamSession.beginConfiguration()
        let output = AVCapturePhotoOutput()
        guard singleCamSession.canAddOutput(output) else {
            singleCamSession.commitConfiguration()
            throw CameraError.configurationFailed
        }
        singleCamSession.addOutput(output)
        singleCamOutput = output
        singleCamSession.commitConfiguration()
        try switchSingleCamInput(to: position)
    }

    /// Only ever called from a block already running on `sessionQueue`.
    private func switchSingleCamInput(to position: AVCaptureDevice.Position) throws {
        singleCamSession.beginConfiguration()
        defer { singleCamSession.commitConfiguration() }

        if let currentInput = singleCamSession.inputs.first as? AVCaptureDeviceInput {
            singleCamSession.removeInput(currentInput)
        }
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: device),
            singleCamSession.canAddInput(input)
        else { throw CameraError.configurationFailed }
        singleCamSession.addInput(input)
    }

    private func captureSingleCam(position: AVCaptureDevice.Position) async throws -> Data {
        try await performOnSessionQueue { try self.switchSingleCamInput(to: position) }
        return try await capture(.singleCam)
    }

    // MARK: Capture delegate bridging

    private enum PhotoOutputSelector: Sendable {
        case multiCamFront
        case multiCamRear
        case singleCam
    }

    private func capture(_ selector: PhotoOutputSelector) async throws -> Data {
        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                let output: AVCapturePhotoOutput?
                switch selector {
                case .multiCamFront: output = self.multiCamFrontOutput
                case .multiCamRear: output = self.multiCamRearOutput
                case .singleCam: output = self.singleCamOutput
                }
                guard let output else {
                    continuation.resume(throwing: CameraError.notConfigured)
                    return
                }
                let delegate = PhotoCaptureDelegate { [weak self] result in
                    guard let self else { return }
                    self.sessionQueue.async {
                        self.activeDelegates.removeValue(forKey: id)
                        continuation.resume(with: result)
                    }
                }
                self.activeDelegates[id] = delegate
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
            }
        }
    }

    /// Runs `work` on `sessionQueue`, bridging back to `async throws`. Every
    /// method above that configures or starts the session goes through this
    /// (or `capture(_:)`, which needs its own continuation shape because the
    /// delegate callback resumes it asynchronously) so session state is only
    /// ever touched from this one queue.
    private func performOnSessionQueue(_ work: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try work()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

/// A capture is one-shot and short-lived, so a fresh delegate per capture
/// (rather than one long-lived delegate routing by output) keeps each
/// capture's completion handler unambiguous. `@unchecked Sendable`: it holds
/// only an escaping closure, never touched concurrently — `AVCapturePhotoOutput`
/// calls its delegate methods serially on its own dispatch queue.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(AVCameraProvider.CameraError.noImageData))
            return
        }
        completion(.success(data))
    }
}
