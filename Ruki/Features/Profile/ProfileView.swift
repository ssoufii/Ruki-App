import SwiftUI

/// Who you are in Ruki and how you're doing — for you alone. The streak is
/// large on purpose, and it is never shared: there is no share button here and
/// there must never be one (D24, RDP-1).
struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    let social: SocialSession
    private let timeline: PrayerTimeline
    private let clock: any ClockProviding
    private let userSettings: UserSettings
    private let historyStore: HistoryStore
    private let notificationAuthorizer: any NotificationAuthorizing
    private let onScheduleAffectingChange: () async -> Void
    private let onDeleteAllData: () async -> Bool
    private let onDebugSendTestPrompt: () async -> Void
    let refreshTrigger: Int

    @State private var showingSettings = false

    init(
        timeline: PrayerTimeline,
        clock: any ClockProviding,
        userSettings: UserSettings,
        historyStore: HistoryStore,
        social: SocialSession,
        notificationAuthorizer: any NotificationAuthorizing,
        onScheduleAffectingChange: @escaping () async -> Void,
        onDeleteAllData: @escaping () async -> Bool,
        onDebugSendTestPrompt: @escaping () async -> Void = {},
        refreshTrigger: Int = 0
    ) {
        _viewModel = State(wrappedValue: ProfileViewModel(timeline: timeline, clock: clock, userSettings: userSettings, historyStore: historyStore))
        self.social = social
        self.timeline = timeline
        self.clock = clock
        self.userSettings = userSettings
        self.historyStore = historyStore
        self.notificationAuthorizer = notificationAuthorizer
        self.onScheduleAffectingChange = onScheduleAffectingChange
        self.onDeleteAllData = onDeleteAllData
        self.onDebugSendTestPrompt = onDebugSendTestPrompt
        self.refreshTrigger = refreshTrigger
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    streakCard
                    statsRow
                    linksCard
                }
                .padding()
            }
            .background(RukiPalette.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task { viewModel.refresh() }
            .onChange(of: refreshTrigger) { _, _ in viewModel.refresh() }
        }
        .sheet(isPresented: $showingSettings, onDismiss: { viewModel.refresh() }) {
            SettingsView(
                viewModel: SettingsViewModel(
                    userSettings: userSettings,
                    notificationAuthorizer: notificationAuthorizer,
                    historyStore: historyStore,
                    clock: clock,
                    onScheduleAffectingChange: onScheduleAffectingChange,
                    onDeleteAllData: onDeleteAllData,
                    onDebugSendTestPrompt: onDebugSendTestPrompt
                ),
                social: social
            )
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(RukiPalette.accent.opacity(0.15)).frame(width: 88, height: 88)
                Text(initial)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(RukiPalette.accent)
            }
            .accessibilityHidden(true)
            Text(social.account?.username ?? String(localized: "Not signed in"))
                .font(.title2.weight(.semibold))
                .foregroundStyle(RukiPalette.primaryText)
            if let since = viewModel.memberSince {
                Text("Using Ruki since \(since.formatted(Date.FormatStyle(timeZone: TorontoCalendar.timeZone).month(.wide).day().year()))")
                    .font(.footnote)
                    .foregroundStyle(RukiPalette.secondaryText)
            }
        }
    }

    private var streakCard: some View {
        VStack(spacing: 6) {
            Text("Current streak")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(RukiPalette.secondaryText)
            Text("\(viewModel.summary.current)")
                .font(.system(size: 84, weight: .bold, design: .rounded))
                .foregroundStyle(RukiPalette.accent)
                .contentTransition(.numericText())
            Text(viewModel.summary.current == 1 ? "prayer in a row" : "prayers in a row")
                .font(.headline)
                .foregroundStyle(RukiPalette.primaryText)
            if let note = viewModel.resetNote {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(RukiPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            Label("Only you can see this", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(RukiPalette.secondaryText.opacity(0.8))
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: "\(viewModel.summary.lifetime)", caption: String(localized: "prayers total"))
            statTile(value: viewModel.onTimePercent.map { "\($0)%" } ?? "–", caption: String(localized: "on time, 30 days"))
            statTile(value: social.isSignedIn ? "\(social.friends.friends.count)/\(social.friends.cap)" : "–", caption: String(localized: "in your circle"))
        }
    }

    private func statTile(value: String, caption: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(RukiPalette.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(caption)
                .font(.caption)
                .foregroundStyle(RukiPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(.horizontal, 6)
        .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                CalendarView(timeline: timeline, clock: clock, userSettings: userSettings, historyStore: historyStore)
            } label: {
                linkRow(symbol: "calendar", title: String(localized: "History"))
            }
            Divider().padding(.leading, 52)
            Button {
                showingSettings = true
            } label: {
                linkRow(symbol: "gearshape", title: String(localized: "Settings"))
            }
        }
        .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func linkRow(symbol: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(RukiPalette.accent)
            Text(title)
                .foregroundStyle(RukiPalette.primaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(RukiPalette.secondaryText.opacity(0.6))
        }
        .padding()
        .contentShape(Rectangle())
    }

    private var initial: String {
        social.account?.username.first.map { String($0).uppercased() } ?? "R"
    }
}
