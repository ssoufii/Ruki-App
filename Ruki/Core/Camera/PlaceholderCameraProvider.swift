import Foundation
import SwiftUI
import UIKit

/// Stands in for `AVCameraProvider` wherever there's no real camera —
/// currently only the Simulator (`AppEnvironment` selects it via
/// `#if targetEnvironment(simulator)`). Generates a clearly-labelled
/// placeholder image instead of touching `AVFoundation`, so the whole
/// check-in flow — including this one — is exercisable without hardware.
struct PlaceholderCameraProvider: CameraProviding {
    private let clock: any ClockProviding

    init(clock: any ClockProviding) {
        self.clock = clock
    }

    nonisolated func isDualCameraSupported() -> Bool { true }

    func requestAuthorization() async -> Bool { true }

    func startSession() async throws {}

    func stopSession() async {}

    nonisolated func makePreviewView() -> AnyView {
        AnyView(
            ZStack {
                RukiPalette.surface
                Text("Simulator — no camera")
                    .font(.subheadline)
                    .foregroundStyle(RukiPalette.secondaryText)
            }
        )
    }

    func capturePhoto(mode: CaptureMode) async throws -> CapturedPhoto {
        let rear = Self.makeImageData(label: "Rear — \(clock.now().formatted(date: .omitted, time: .standard))")
        guard mode == .dual else {
            return CapturedPhoto(frontImageData: nil, rearImageData: rear)
        }
        let front = Self.makeImageData(label: "Front — \(clock.now().formatted(date: .omitted, time: .standard))")
        return CapturedPhoto(frontImageData: front, rearImageData: rear)
    }

    /// A small, clearly-labelled square so a placeholder capture can never be
    /// mistaken for a real photo if it ever ended up somewhere it shouldn't.
    private static func makeImageData(label: String) -> Data {
        let size = CGSize(width: 320, height: 320)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 18),
                .paragraphStyle: paragraphStyle
            ]
            let text = "SIMULATOR\n\(label)"
            text.draw(
                with: CGRect(x: 16, y: size.height / 2 - 30, width: size.width - 32, height: 60),
                options: .usesLineFragmentOrigin,
                attributes: attributes,
                context: nil
            )
        }
        return image.pngData() ?? Data()
    }
}
