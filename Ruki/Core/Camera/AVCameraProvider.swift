import AVFoundation
import Foundation
import SwiftUI

/// Real camera capture. Never used on the Simulator (no camera hardware at
/// all) — `AppEnvironment` selects `PlaceholderCameraProvider` there via
/// `#if targetEnvironment(simulator)`.
///
/// An `actor`, because Apple's own guidance is to configure and drive a
/// capture session away from the main thread. The actual
/// `AVCapturePhotoCaptureDelegate` conformance lives on the private
/// `PhotoCaptureDelegate` below (that protocol requires `NSObjectProtocol`,
/// which an actor can't provide) — its callbacks arrive on an arbitrary
/// queue with no actor context, so they hop back in via `Task` to resume the
/// continuation that's waiting, the standard Swift 6 pattern for a
/// delegate-based Apple API. `makePreviewView()` is the one `@MainActor`
/// member, since `AVCaptureVideoPreviewLayer` is a UIKit type.
actor AVCameraProvider: CameraProviding {
    enum CameraError: Error {
        case configurationFailed
        case notConfigured
        case noImageData
    }

    /// `nonisolated(unsafe)`: `makePreviewView()` is deliberately `@MainActor`
    /// (SwiftUI/UIKit need the preview layer built on the main thread) and
    /// has to read these two properties across that isolation boundary.
    /// Safe in practice — `AVCaptureSession` is documented to tolerate being
    /// driven from a session queue while a preview layer on another thread
    /// reads it live, which is exactly this split; `multiCamConfigured` only
    /// ever flips once, during `startSession()`, before any preview view is
    /// requested.
    private nonisolated(unsafe) let multiCamSession = AVCaptureMultiCamSession()
    private nonisolated(unsafe) let singleCamSession = AVCaptureSession()
    private nonisolated(unsafe) var multiCamConfigured = false

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
        guard !sessionStarted else { return }

        if AVCaptureMultiCamSession.isMultiCamSupported, configureMultiCamSession() {
            multiCamConfigured = true
            multiCamSession.startRunning()
        } else {
            multiCamConfigured = false
            try configureSingleCamSession(position: .front)
            singleCamSession.startRunning()
        }
        sessionStarted = true
    }

    func stopSession() async {
        if multiCamSession.isRunning { multiCamSession.stopRunning() }
        if singleCamSession.isRunning { singleCamSession.stopRunning() }
        sessionStarted = false
    }

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
                ? try await capture(from: multiCamRearOutput)
                : try await captureSingleCam(position: .back)
            return CapturedPhoto(frontImageData: nil, rearImageData: rear)
        case .simultaneousDualCamera:
            async let front = capture(from: multiCamFrontOutput)
            async let rear = capture(from: multiCamRearOutput)
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
        try switchSingleCamInput(to: position)
        return try await capture(from: singleCamOutput)
    }

    // MARK: Capture delegate bridging

    private func capture(from output: AVCapturePhotoOutput?) async throws -> Data {
        guard let output else { throw CameraError.notConfigured }
        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate { [weak self] result in
                Task { await self?.finishCapture(id: id, result: result, continuation: continuation) }
            }
            activeDelegates[id] = delegate
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }

    private func finishCapture(id: UUID, result: Result<Data, Error>, continuation: CheckedContinuation<Data, Error>) {
        activeDelegates.removeValue(forKey: id)
        continuation.resume(with: result)
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
