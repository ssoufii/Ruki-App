import Foundation

/// How a single capture is physically taken. Pure decision logic, kept apart
/// from `AVCameraProvider` so it's testable without `AVFoundation` or
/// hardware — this *is* the "shared code path" RUKI-021 asks for: sequential
/// fallback isn't a separate feature, it's what `.dual` resolves to whenever
/// simultaneous capture isn't available, feature-detected via
/// `dualCameraSupported` with no user-facing setting.
enum CameraCaptureStrategy: Sendable, Equatable {
    case rearOnly
    case simultaneousDualCamera
    case sequentialFrontThenRear
}

enum CameraCaptureStrategyResolver {
    static func resolve(mode: CaptureMode, dualCameraSupported: Bool) -> CameraCaptureStrategy {
        switch mode {
        case .spaceOnly:
            return .rearOnly
        case .dual:
            return dualCameraSupported ? .simultaneousDualCamera : .sequentialFrontThenRear
        }
    }
}
