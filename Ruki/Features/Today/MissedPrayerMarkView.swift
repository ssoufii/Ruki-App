import SwiftUI

/// RUKI-026: the sheet a closed, unrecorded prayer window opens into.
/// "I prayed" is shared with the circle as a post with no photo (D49) — a positive
/// claim, never an absence. "I didn't" is private and on-device only (RDP-2):
/// nothing here produces a network event for it. Neutral phrasing throughout
/// (CLAUDE.md Tone): no red, no "FAILED", no guilt copy.
struct MissedPrayerMarkView: View {
    let prayerName: String
    /// `true` when signed in, so "I prayed" will reach the circle. The copy must match what really happens.
    let sharesWithCircle: Bool
    let onMark: (MarkSnapshot.Kind) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Did you pray \(prayerName)?")
                .font(.title2)
                .foregroundStyle(RukiPalette.primaryText)

            Spacer()

            VStack(spacing: 8) {
                Button {
                    onMark(.prayed)
                } label: {
                    Text("I prayed")
                        .font(.headline)
                        .foregroundStyle(RukiPalette.background)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 12))

                Text(sharesWithCircle
                    ? "Your circle will see that you prayed, without a photo, until the next prayer begins."
                    : "Saved on your device.")
                    .font(.footnote)
                    .foregroundStyle(RukiPalette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(spacing: 4) {
                Button("I didn't") {
                    onMark(.missed)
                }
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)

                Text("Private. This never leaves your device.")
                    .font(.footnote)
                    .foregroundStyle(RukiPalette.secondaryText.opacity(0.8))
            }

            Button("Cancel", action: onCancel)
                .font(.footnote)
                .foregroundStyle(RukiPalette.secondaryText)
        }
        .padding(.bottom, 32)
        .background(RukiPalette.background)
    }
}

#Preview {
    MissedPrayerMarkView(prayerName: "Dhuhr", sharesWithCircle: true, onMark: { _ in }, onCancel: {})
}
