import SwiftUI

/// RUKI-026: the sheet a closed, unrecorded prayer window opens into. Both
/// paths are private and on-device only (RDP-2) — nothing here ever
/// produces a network event, whichever the user answers. Neutral phrasing
/// throughout (CLAUDE.md Tone): no red, no "FAILED", no guilt copy.
struct MissedPrayerMarkView: View {
    let prayerName: String
    let onMark: (MarkSnapshot.Kind) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Did you pray \(prayerName)?")
                .font(.title2)
                .foregroundStyle(RukiPalette.primaryText)

            Text("This is just for your own records. It never leaves your device.")
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

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
            .padding(.horizontal)

            Button("I didn't") {
                onMark(.missed)
            }
            .font(.subheadline)
            .foregroundStyle(RukiPalette.secondaryText)

            Button("Cancel", action: onCancel)
                .font(.footnote)
                .foregroundStyle(RukiPalette.secondaryText)
        }
        .padding(.bottom, 32)
        .background(RukiPalette.background)
    }
}

#Preview {
    MissedPrayerMarkView(prayerName: "Dhuhr", onMark: { _ in }, onCancel: {})
}
