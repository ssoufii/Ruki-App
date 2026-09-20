import AVFoundation
import SwiftUI
import UIKit

/// Wraps `AVCaptureVideoPreviewLayer` for `AVCameraProvider.makePreviewView()`
/// — the standard `UIViewRepresentable` shape for a live camera feed
/// (`layerClass` override, matching Apple's own AVCam sample).
struct CameraPreviewRepresentable: UIViewRepresentable {
    /// Hands the layer to the provider, which alone knows how the running
    /// session is wired (a multi-cam session needs an explicit preview
    /// connection; a plain one just takes `layer.session`). Holding a closure
    /// instead of an `AVCaptureSession` also keeps this struct free of any
    /// non-Sendable stored state, so it compiles the same on every Swift 6.x.
    let attach: @MainActor (AVCaptureVideoPreviewLayer) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        attach(view.videoPreviewLayer)
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
