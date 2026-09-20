import SwiftUI

/// RUKI-034: the second of pause's two taps. No reason field, no
/// confirmation step — picking a duration pauses immediately (RDP-3:
/// stepping away never requires an explanation).
struct PauseDurationView: View {
    let onSelect: (PauseDuration) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Pause check-ins")
                .font(.title2)
                .foregroundStyle(RukiPalette.primaryText)
                .padding(.top, 32)

            Text("No reason needed. You can turn it back on anytime.")
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)

            ForEach(PauseDuration.allCases, id: \.label) { duration in
                Button {
                    onSelect(duration)
                } label: {
                    Text(duration.label)
                        .font(.headline)
                        .foregroundStyle(RukiPalette.primaryText)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            Spacer()
        }
        .background(RukiPalette.background)
    }
}

#Preview {
    PauseDurationView(onSelect: { _ in })
}
