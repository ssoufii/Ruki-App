import SwiftUI

/// RUKI-036: madhab, check-in window, per-prayer toggles, sound, Space Only
/// default, a pause row, and two read-only rows (calculation method,
/// notification status). Calculation method has no picker — the frozen
/// provider (D27) ignores it, matching D34's onboarding decision; a working
/// control here would mislead the person testing this build.
struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @State private var showingPause = false

    var body: some View {
        Form {
            Section("Prayer times") {
                Picker("Asr madhab", selection: $viewModel.madhab) {
                    Text("Shafi'i / Maliki / Hanbali").tag(Madhab.standard)
                    Text("Hanafi").tag(Madhab.hanafi)
                }
                LabeledContent("Calculation method", value: "ISNA — Toronto")
            }

            Section("Check-in window") {
                Picker("Window length", selection: $viewModel.checkInWindowMinutes) {
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
                Text("Maghrib is always at most 20 minutes, and Fajr always runs from adhan to sunrise, whatever you pick here.")
                    .font(.caption)
                    .foregroundStyle(RukiPalette.secondaryText)
            }

            Section("Prayers") {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    Toggle(
                        prayer.displayName,
                        isOn: Binding(
                            get: { viewModel.isPrayerEnabled(prayer) },
                            set: { viewModel.setPrayer(prayer, enabled: $0) }
                        )
                    )
                }
            }

            Section("Notifications") {
                Toggle("Sound", isOn: $viewModel.soundEnabled)
                LabeledContent("Status", value: viewModel.notificationStatus.label)
            }

            Section("Capture") {
                Toggle("Space Only by default", isOn: $viewModel.spaceOnlyDefault)
                Text("Uses the rear camera only, for when you'd rather not appear in frame. You can still switch it per check-in.")
                    .font(.caption)
                    .foregroundStyle(RukiPalette.secondaryText)
            }

            Section {
                Button {
                    showingPause = true
                } label: {
                    LabeledContent("Check-ins", value: viewModel.isPaused ? "Paused" : "Active")
                }
                .disabled(viewModel.isPaused)
            }
        }
        .task { await viewModel.refresh() }
        .sheet(isPresented: $showingPause) {
            PauseDurationView { duration in
                viewModel.pause(for: duration)
                showingPause = false
            }
        }
    }
}

private extension NotificationAuthorizationStatus {
    var label: String {
        switch self {
        case .notDetermined: String(localized: "Not asked yet")
        case .denied: String(localized: "Turned off in system settings")
        case .authorized: String(localized: "On")
        case .provisional: String(localized: "On, quietly")
        }
    }
}

#Preview {
    let environment = AppEnvironment()
    return SettingsView(
        viewModel: SettingsViewModel(
            userSettings: environment.userSettings,
            notificationAuthorizer: environment.notificationAuthorizer,
            historyStore: environment.historyStore,
            clock: environment.clock,
            onScheduleAffectingChange: {}
        )
    )
}
