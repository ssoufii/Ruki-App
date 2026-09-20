import AVFoundation
import SwiftUI
import UIKit

/// Wraps `AVCaptureVideoPreviewLayer` for `AVCameraProvider.makePreviewView()`
/// — the standard `UIViewRepresentable` shape for a live camera feed
/// (`layerClass` override, matching Apple's own AVCam sample).
struct CameraPreviewRepresentable: UIViewRepresentable {
    /// Plain `@MainActor`-inferred storage, like every other member of this
    /// `UIViewRepresentable` — no `nonisolated`/`nonisolated(unsafe)`
    /// override. Earlier attempts tried keeping this whole type callable
    /// off the main actor (to match a `nonisolated makePreviewView()`), but
    /// marking just the property `nonisolated(unsafe)` still left its
    /// assignment in a `nonisolated init` rejected by the compiler (`main
    /// actor-isolated property 'session' can not be mutated from a
    /// nonisolated context`, issue #20). `AVCameraProvider.makePreviewView()`
    /// is now itself `@MainActor`, and its only caller is already on the
    /// main actor, so this type never needs to be built off it.
    private let session: AVCaptureSession

    init(session: AVCaptureSession) {
        self.session = session
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // Safe to force-cast: `layerClass` above guarantees `layer` is
            // always this type for every instance of this view.
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
