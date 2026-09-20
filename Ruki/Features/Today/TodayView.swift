import Combine
import SwiftUI

/// T2: the app's home screen once onboarding is done. Shows the current or
/// next prayer with a gentle countdown, a live card for whatever's open right
/// now, and today's five prayer rows. Pause (RUKI-034), Settings (RUKI-036),
/// and History (RUKI-032) are real flows from here; check-in is still a
/// doorway — `ComingSoonScreen` until RUKI-020 gives it a real
/// `CameraProviding` to wire in.
struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @State private var showingPause = false
    @State private var showingCheckIn = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var markingRow: TodayViewModel.Row?

    /// Kept only to hand to `CalendarView` (RUKI-032) when History is opened
    /// — `viewModel` already owns its own copy for Today's own rows.
    private let timeline: PrayerTimeline
    private let clock: any ClockProviding
    private let userSettings: UserSettings
    private let historyStore: HistoryStore
    private let notificationAuthorizer: any NotificationAuthorizing

    /// Called after a pause or a schedule-affecting settings change is
    /// recorded (RUKI-034, RUKI-036), so notifications get re-planned
    /// without this view owning any scheduling logic itself.
    let onScheduleAffectingChange: () async -> Void

    /// RUKI-037: "Delete my data on this device", forwarded to
    /// `AppEnvironment` — wiping SwiftData and cancelling notifications
    /// needs the scheduler this view never otherwise touches.
    let onDeleteAllData: () async -> Void

    /// T3 DEBUG tools only, forwarded through to `SettingsViewModel` — see
    /// its own doc comment for why this is threaded unconditionally.
    let onDebugSendTestPrompt: () async -> Void

    /// Minute ticks only trigger a re-read of `clock.now()`; they never stand
    /// in for it themselves (CLAUDE.md's no-`Date()` rule is about the app's
    /// notion of "now", not about what wakes the UI up to ask for it again).
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(
        timeline: PrayerTimeline,
        clock: any ClockProviding,
        userSettings: UserSettings,
        historyStore: HistoryStore,
        notificationAuthorizer: any NotificationAuthorizing,
        onScheduleAffectingChange: @escaping () async -> Void,
        onDeleteAllData: @escaping () async -> Void,
        onDebugSendTestPrompt: @escaping () async -> Void = {}
    ) {
        _viewModel = State(
            wrappedValue: TodayViewModel(timeline: timeline, clock: clock, userSettings: userSettings, historyStore: historyStore)
        )
        self.timeline = timeline
        self.clock = clock
        self.userSettings = userSettings
        self.historyStore = historyStore
        self.notificationAuthorizer = notificationAuthorizer
        self.onScheduleAffectingChange = onScheduleAffectingChange
        self.onDeleteAllData = onDeleteAllData
        self.onDebugSendTestPrompt = onDebugSendTestPrompt
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text(viewModel.headline)
                        .font(.title2)
                        .foregroundStyle(RukiPalette.primaryText)
                        .accessibilityAddTraits(.updatesFrequently)
                    Spacer()
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(RukiPalette.secondaryText)
                    }
                    .accessibilityLabel("Settings")
                }

                if let activeRow = viewModel.activeRow {
                    checkInCard(for: activeRow)
                }

                VStack(spacing: 0) {
                    ForEach(viewModel.rows) { row in
                        if row.id != viewModel.rows.first?.id {
                            Divider()
                        }
                        PrayerRowView(row: row) {
                            markingRow = row
                        }
                    }
                }
                .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 16))

                HStack {
                    Button {
                        showingHistory = true
                    } label: {
                        Text("History")
                            .font(.subheadline)
                            .foregroundStyle(RukiPalette.secondaryText)
                    }
                    Spacer()
                    Button {
                        showingPause = true
                    } label: {
                        Text("Pause check-ins")
                            .font(.subheadline)
                            .foregroundStyle(RukiPalette.secondaryText)
                    }
                }
            }
            .padding()
        }
        .background(RukiPalette.background)
        .task { viewModel.refresh() }
        .onReceive(ticker) { _ in viewModel.refresh() }
        .sheet(isPresented: $showingPause) {
            PauseDurationView { duration in
                viewModel.pause(for: duration)
                showingPause = false
                Task { await onScheduleAffectingChange() }
            }
        }
        .sheet(isPresented: $showingCheckIn) {
            ComingSoonScreen(title: "Check-in")
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                viewModel: SettingsViewModel(
                    userSettings: userSettings,
                    notificationAuthorizer: notificationAuthorizer,
                    historyStore: historyStore,
                    clock: clock,
                    onScheduleAffectingChange: onScheduleAffectingChange,
                    onDeleteAllData: onDeleteAllData,
                    onDebugSendTestPrompt: onDebugSendTestPrompt
                )
            )
            .onDisappear { viewModel.refresh() }
        }
        .sheet(isPresented: $showingHistory) {
            NavigationStack {
                CalendarView(timeline: timeline, clock: clock, userSettings: userSettings, historyStore: historyStore)
            }
        }
        .sheet(item: $markingRow) { row in
            MissedPrayerMarkView(
                prayerName: row.slot.prayer.displayName,
                onMark: { kind in
                    viewModel.mark(row, as: kind)
                    markingRow = nil
                },
                onCancel: { markingRow = nil }
            )
        }
    }

    @ViewBuilder
    private func checkInCard(for row: TodayViewModel.Row) -> some View {
        switch row.status {
        case .openOnTime, .openLate:
            Button {
                showingCheckIn = true
            } label: {
                Text("Check in for \(row.slot.prayer.displayName)")
                    .font(.headline)
                    .foregroundStyle(RukiPalette.background)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 12))
        case .checkedInOnTime:
            statusCard(String(localized: "You checked in for \(row.slot.prayer.displayName)."))
        case .checkedInLate:
            statusCard(String(localized: "Checked in late for \(row.slot.prayer.displayName) — still counts."))
        case .paused:
            statusCard(String(localized: "Check-ins are paused."))
        case .upcoming, .markedPrayed, .missed, .notTracked:
            EmptyView()
        }
    }

    private func statusCard(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(RukiPalette.primaryText)
            .padding()
            .frame(maxWidth: .infinity)
            .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PrayerRowView: View {
    let row: TodayViewModel.Row
    /// RUKI-026: only a closed, unrecorded window (`.missed`) opens the
    /// private mark sheet — every other status is informational only.
    let onTapMissed: () -> Void

    var body: some View {
        if row.status == .missed {
            Button(action: onTapMissed) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack {
            Image(systemName: row.status.symbolName)
                .foregroundStyle(RukiPalette.secondaryText)
                .accessibilityHidden(true)
            Text(row.slot.prayer.displayName)
                .font(.body)
                .foregroundStyle(RukiPalette.primaryText)
            Spacer()
            Text(row.status.label)
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let environment = AppEnvironment()
    return TodayView(
        timeline: environment.timeline,
        clock: environment.clock,
        userSettings: environment.userSettings,
        historyStore: environment.historyStore,
        notificationAuthorizer: environment.notificationAuthorizer,
        onScheduleAffectingChange: {},
        onDeleteAllData: {}
    )
}
