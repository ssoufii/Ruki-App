import SwiftUI

/// RUKI-019: prompt → tap → "Have you prayed X?" → I've prayed → camera →
/// review → post, in as few taps as the flow allows. The camera is
/// structurally unreachable before the user affirms (RDP-4) —
/// `CheckInViewModel.affirmPrayed()` is the one path that ever touches
/// `CameraProviding`.
///
/// **Not yet reachable from `TodayView`.** There's no real `CameraProviding`
/// implementation to inject — the Simulator placeholder and the real
/// `AVCameraProvider` are both RUKI-020's job. Wiring this in before then
/// would mean shipping a test fake into a real screen.
struct CheckInFlowView: View {
    @State var viewModel: CheckInViewModel

    var body: some View {
        VStack(spacing: 24) {
            switch viewModel.state {
            case .affirm:
                affirmStep
            case .capturing:
                ProgressView()
                    .tint(RukiPalette.accent)
            case .review(let photo):
                reviewStep(photo: photo)
            case .posted:
                postedStep
            case .failed:
                failedStep
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RukiPalette.background)
    }

    private var affirmStep: some View {
        VStack(spacing: 24) {
            Text(viewModel.affirmPrompt)
                .font(.title2)
                .foregroundStyle(RukiPalette.primaryText)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.affirmPrayed() }
            } label: {
                Text("I've prayed")
                    .font(.headline)
                    .foregroundStyle(RukiPalette.background)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func reviewStep(photo: CapturedPhoto) -> some View {
        VStack(spacing: 16) {
            if viewModel.isLate {
                Text("Checked in late — still counts.")
                    .font(.subheadline)
                    .foregroundStyle(RukiPalette.secondaryText)
            }

            Text("Photo captured")
                .font(.body)
                .foregroundStyle(RukiPalette.secondaryText)

            Button {
                viewModel.post()
            } label: {
                Text("Post")
                    .font(.headline)
                    .foregroundStyle(RukiPalette.background)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 12))

            Button("Retake") {
                Task { await viewModel.retake() }
            }
            .font(.subheadline)
            .foregroundStyle(RukiPalette.secondaryText)
        }
    }

    private var postedStep: some View {
        Text(viewModel.postedMessage)
            .font(.headline)
            .foregroundStyle(RukiPalette.primaryText)
    }

    private var failedStep: some View {
        VStack(spacing: 16) {
            Text("Couldn't capture a photo.")
                .foregroundStyle(RukiPalette.secondaryText)
            Button("Try again") {
                Task { await viewModel.affirmPrayed() }
            }
            .font(.headline)
            .foregroundStyle(RukiPalette.accent)
        }
    }
}

#Preview {
    let environment = AppEnvironment()
    let slot = environment.timeline.slots(onDayOf: environment.clock.now()).first!
    return CheckInFlowView(
        viewModel: CheckInViewModel(
            slot: slot,
            isLate: false,
            captureMode: .dual,
            expiresAt: slot.window.end,
            cameraProvider: FakeCameraProvider(),
            clock: environment.clock,
            historyStore: environment.historyStore
        )
    )
}

/// Preview-only stand-in so this file's `#Preview` doesn't need a real
/// camera. `RukiTests/TestSupport/FakeCameraProvider` is the one used by
/// tests; this is a separate, minimal copy because test types aren't
/// linked into the app target previews run against.
private struct FakeCameraProvider: CameraProviding {
    nonisolated func isDualCameraSupported() -> Bool { true }

    func capturePhoto(mode: CaptureMode) async throws -> CapturedPhoto {
        CapturedPhoto(frontImageData: Data([0x01]), rearImageData: Data([0x02]))
    }
}
