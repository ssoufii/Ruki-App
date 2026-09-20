import Foundation
import Testing
@testable import Ruki

@Suite("PlaceholderCameraProvider")
struct PlaceholderCameraProviderTests {
    private let clock = FixedClock(date: ISO8601DateFormatter().date(from: "2026-09-19T09:40:00Z")!)

    @Test("Dual mode produces both a front and a rear image")
    func dualModeProducesBothFrames() async throws {
        let provider = PlaceholderCameraProvider(clock: clock)

        let photo = try await provider.capturePhoto(mode: .dual)

        #expect(photo.frontImageData?.isEmpty == false)
        #expect(photo.rearImageData.isEmpty == false)
    }

    @Test("Space Only produces a rear image only")
    func spaceOnlyProducesRearOnly() async throws {
        let provider = PlaceholderCameraProvider(clock: clock)

        let photo = try await provider.capturePhoto(mode: .spaceOnly)

        #expect(photo.frontImageData == nil)
        #expect(photo.rearImageData.isEmpty == false)
    }

    @Test("Reports dual-camera support, is pre-authorized, and never leaves a session hanging")
    func supportsDualAndAuthorization() async throws {
        let provider = PlaceholderCameraProvider(clock: clock)

        #expect(provider.isDualCameraSupported() == true)
        #expect(await provider.requestAuthorization() == true)
        try await provider.startSession()
        await provider.stopSession()
    }
}
