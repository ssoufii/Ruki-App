import AVFoundation
import SwiftUI
import UIKit

/// Wraps `AVCaptureVideoPreviewLayer` for `AVCameraProvider.makePreviewView()`
/// — the standard `UIViewRepresentable` shape for a live camera feed
/// (`layerClass` override, matching Apple's own AVCam sample).
struct CameraPreviewRepresentable: UIViewRepresentable {
    /// `nonisolated(unsafe)`, not just a `nonisolated init`: `UIViewRepresentable`
    /// (via `View`) infers `@MainActor` isolation for every member of this
    /// type, including a stored property — marking only the init `nonisolated`
    /// still leaves assigning to this `@MainActor`-isolated property from
    /// that nonisolated init rejected (`main actor-isolated property 'session'
    /// can not be mutated from a nonisolated context`, the error three prior
    /// attempts on issue #20 kept landing back on). Safe in practice for the
    /// same reason `AVCameraProvider` itself reads its session properties
    /// without hopping isolation: `AVCaptureSession` is documented to
    /// tolerate being read here while driven from elsewhere, and this value
    /// never changes after init.
    private nonisolated(unsafe) let session: AVCaptureSession

    /// Building this struct is just storing a reference, not touching UIKit
    /// (`makeUIView` does that, and stays implicitly `@MainActor` as normal).
    /// Without this override, `AVCameraProvider.makePreviewView()` —
    /// `nonisolated` on purpose, so it can be called synchronously without
    /// isolation — couldn't construct this type at all.
    nonisolated init(session: AVCaptureSession) {
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
