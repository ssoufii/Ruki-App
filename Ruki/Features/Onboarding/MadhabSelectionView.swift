import SwiftUI

/// RUKI-009 (**partial by design** — D31, D34): only Asr madhab is
/// selectable in M1. Calculation method is shown read-only ("ISNA, Toronto")
/// since the frozen provider (D27) ignores whatever's picked, and a working
/// picker would mislead the person testing this build. The 3-session (Shia
/// combining) practice profile is out of scope for v1 (D31) — this screen
/// only ever writes `madhab`, nothing else.
struct MadhabSelectionView: View {
    @Binding var madhab: Madhab
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Asr timing")
                .font(.title)
                .foregroundStyle(RukiPalette.primaryText)

            Text("Choose which convention you follow for when Asr begins. You can change this later in Settings.")
                .font(.body)
                .foregroundStyle(RukiPalette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Picker("Asr madhab", selection: $madhab) {
                Text("Shafi'i / Maliki / Hanbali").tag(Madhab.standard)
                Text("Hanafi").tag(Madhab.hanafi)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            VStack(spacing: 4) {
                Text("Calculation method")
                    .font(.caption)
                    .foregroundStyle(RukiPalette.secondaryText)
                Text("ISNA — Toronto")
                    .font(.body)
                    .foregroundStyle(RukiPalette.primaryText)
            }
            .padding(.top, 8)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(RukiPalette.background)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding(.bottom, 32)
        .background(RukiPalette.background)
    }
}

#Preview {
    MadhabSelectionView(madhab: .constant(.standard), onContinue: {})
}
