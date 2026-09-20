import AVFoundation
import SwiftUI
import UIKit

/// Wraps `AVCaptureVideoPreviewLayer` for `AVCameraProvider.makePreviewView()`
/// — the standard `UIViewRepresentable` shape for a live camera feed
/// (`layerClass` override, matching Apple's own AVCam sample).
struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

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
