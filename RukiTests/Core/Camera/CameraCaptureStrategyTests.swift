import Testing
@testable import Ruki

@Suite("CameraCaptureStrategyResolver")
struct CameraCaptureStrategyTests {
    @Test("Space Only always resolves to rear-only, regardless of multi-cam support")
    func spaceOnlyIsAlwaysRearOnly() {
        #expect(CameraCaptureStrategyResolver.resolve(mode: .spaceOnly, dualCameraSupported: true) == .rearOnly)
        #expect(CameraCaptureStrategyResolver.resolve(mode: .spaceOnly, dualCameraSupported: false) == .rearOnly)
    }

    @Test("Dual mode captures simultaneously when multi-cam is supported")
    func dualUsesSimultaneousWhenSupported() {
        #expect(
            CameraCaptureStrategyResolver.resolve(mode: .dual, dualCameraSupported: true) == .simultaneousDualCamera
        )
    }

    @Test("Dual mode falls back to sequential front-then-rear when multi-cam isn't supported (RUKI-021)")
    func dualFallsBackToSequentialWhenUnsupported() {
        #expect(
            CameraCaptureStrategyResolver.resolve(mode: .dual, dualCameraSupported: false)
                == .sequentialFrontThenRear
        )
    }
}
