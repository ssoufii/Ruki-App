import Combine
import SwiftUI

/// The Today tab: the prayer that's open right now, then the day at a glance —
/// five equal circles, one per prayer. Deliberately centered and symmetric; the
/// per-prayer detail lives in the hero card, so the strip stays quiet.
/// RUKI-036's settings and the history calendar live on the Profile tab.
struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @State private var showingPause = false
    @State private var checkInRow: TodayViewModel.Row?
    @State private var markingRow: TodayViewModel.Row?
    @Environment(\.scenePhase) private var scenePhase

    private let cameraProvider: any CameraProviding
    private let social: SocialSession
    private let clock: any ClockProviding

    /// Called after pause/resume so the notification horizon re-plans (RUKI-034).
    let onScheduleAffectingChange: () async -> Void

    /// Bumped by `AppRouter` whenever a check-in cover closes, so this screen
    /// re-reads history instead of showing the state from before it opened.
    let refreshTrigger: Int

    /// Minute ticks only trigger a re-read of `clock.now()`; they never stand
    /// in for it themselves (CLAUDE.md's no-`Date()` rule is about the app's
    /// notion of "now", not about what wakes the UI up to ask for it again).
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(
        timeline: PrayerTimeline,
        clock: any ClockProviding,
        userSettings: UserSettings,
        historyStore: HistoryStore,
        cameraProvider: any CameraProviding,
        social: SocialSession,
        onScheduleAffectingChange: @escaping () async -> Void,
        refreshTrigger: Int = 0
    ) {
        _viewModel = State(
            wrappedValue: TodayViewModel(timeline: timeline, clock: clock, userSettings: userSettings, historyStore: historyStore)
        )
        self.cameraProvider = cameraProvider
        self.social = social
        self.clock = clock
        self.onScheduleAffectingChange = onScheduleAffectingChange
        self.refreshTrigger = refreshTrigger
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                ForEach(social.pendingInvitations) { invitation in
                    invitationCard(invitation)
                }

                heroCard

                prayerStrip

                pauseButton
            }
            .padding()
        }
        .background(RukiPalette.background)
        .task {
            viewModel.refresh()
            await social.refreshQuietly()
        }
        .onReceive(ticker) { _ in
            viewModel.refresh()
            Task { await social.refreshQuietly() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await social.refreshQuietly() } }
        }
        .onChange(of: refreshTrigger) { _, _ in viewModel.refresh() }
        .sheet(isPresented: $showingPause) {
            PauseDurationView { duration in
                viewModel.pause(for: duration)
                showingPause = false
                Task { await onScheduleAffectingChange() }
            }
        }
        .sheet(item: $checkInRow) { row in
            CheckInFlowView(viewModel: viewModel.makeCheckInViewModel(for: row, cameraProvider: cameraProvider, publisher: social))
                .onDisappear { viewModel.refresh() }
        }
        .sheet(item: $markingRow) { row in
            MissedPrayerMarkView(
                prayerName: row.slot.prayer.displayName,
                sharesWithCircle: social.isSignedIn,
                onMark: { kind in
                    viewModel.mark(row, as: kind, publisher: social)
                    markingRow = nil
                },
                onCancel: { markingRow = nil }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 2) {
            Text("Ruki")
                .font(.title3.weight(.semibold))
                .foregroundStyle(RukiPalette.primaryText)
            Text(clock.now().formatted(Date.FormatStyle(timeZone: TorontoCalendar.timeZone).weekday(.wide).month(.wide).day()))
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(RukiPalette.accent.opacity(0.14)).frame(width: 76, height: 76)
                Image(systemName: heroPrayer.symbolName)
                    .font(.system(size: 32))
                    .foregroundStyle(RukiPalette.accent)
            }
            .accessibilityHidden(true)

            if let active = viewModel.activeRow {
                Text(active.slot.prayer.displayName)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(RukiPalette.primaryText)
            }

            Text(viewModel.headline)
                .font(viewModel.activeRow == nil ? .title3 : .subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(viewModel.activeRow == nil ? RukiPalette.primaryText : RukiPalette.secondaryText)
                .accessibilityAddTraits(.updatesFrequently)

            if let active = viewModel.activeRow {
                checkInCard(for: active)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(RukiPalette.accent.opacity(0.12)))
    }

    private var prayerStrip: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(viewModel.rows) { row in
                    PrayerChip(row: row, isActive: row.id == viewModel.activeRow?.id) {
                        markingRow = row
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if tracked > 0 {
                Text("\(completed) of \(tracked) prayers today")
                    .font(.footnote)
                    .foregroundStyle(RukiPalette.secondaryText)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(RukiPalette.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
    }

    private var pauseButton: some View {
        Button {
            if viewModel.isPaused {
                // RDP-3: resuming is one tap, no confirmation — pausing itself
                // needs no reason, so turning it back on shouldn't need one either.
                viewModel.resume()
                Task { await onScheduleAffectingChange() }
            } else {
                showingPause = true
            }
        } label: {
            Text(viewModel.isPaused ? "Resume check-ins" : "Pause check-ins")
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)
        }
    }

    // MARK: Pieces

    /// The prayer the hero card's icon shows: the open one, else the next to come.
    private var heroPrayer: Prayer {
        viewModel.activeRow?.slot.prayer
            ?? viewModel.rows.first { $0.status == .upcoming }?.slot.prayer
            ?? .fajr
    }

    private var tracked: Int { viewModel.rows.filter { $0.status != .notTracked }.count }

    private var completed: Int {
        viewModel.rows.filter { [.checkedInOnTime, .checkedInLate, .markedPrayed].contains($0.status) }.count
    }

    @ViewBuilder
    private func checkInCard(for row: TodayViewModel.Row) -> some View {
        switch row.status {
        case .openOnTime, .openLate:
            Button {
                checkInRow = row
            } label: {
                Text("Check in for \(row.slot.prayer.displayName)")
                    .font(.headline)
                    .foregroundStyle(RukiPalette.background)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 14))
        case .checkedInOnTime:
            statusPill(String(localized: "You checked in for \(row.slot.prayer.displayName)."), symbol: "checkmark.circle.fill")
        case .checkedInLate:
            statusPill(String(localized: "Checked in late for \(row.slot.prayer.displayName) — still counts."), symbol: "checkmark.circle.fill")
        case .paused:
            statusPill(String(localized: "Check-ins are paused."), symbol: "pause.circle")
        case .upcoming, .markedPrayed, .missed, .notTracked:
            EmptyView()
        }
    }

    private func statusPill(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(RukiPalette.primaryText)
            .multilineTextAlignment(.center)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(RukiPalette.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
    }

    /// A friend asked you into their circle. In-app, not a system push: a push
    /// needs the real backend (D43). Declining just removes the request.
    private func invitationCard(_ friend: Friend) -> some View {
        VStack(spacing: 12) {
            Label("\(friend.username) invited you to their circle", systemImage: "person.2.fill")
                .font(.headline)
                .foregroundStyle(RukiPalette.primaryText)
                .multilineTextAlignment(.center)
            if let message = social.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(RukiPalette.secondaryText)
            }
            HStack(spacing: 12) {
                Button {
                    Task { await social.accept(friend) }
                } label: {
                    Text("Accept")
                        .font(.headline)
                        .foregroundStyle(RukiPalette.background)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .background(RukiPalette.accent, in: RoundedRectangle(cornerRadius: 12))
                Button {
                    Task { await social.remove(friend) }
                } label: {
                    Text("Not now")
                        .font(.headline)
                        .foregroundStyle(RukiPalette.primaryText)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .background(RukiPalette.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Prayer chip

/// One prayer in the day strip. Every chip is the same size so the row stays
/// symmetric; state is carried by fill, ring and icon rather than by text.
private struct PrayerChip: View {
    let row: TodayViewModel.Row
    let isActive: Bool
    /// Only a closed, unrecorded prayer is tappable (RUKI-026); every other status is informational.
    let onTapMissed: () -> Void

    var body: some View {
        Group {
            if row.status == .missed {
                Button(action: onTapMissed) { chip }
            } else {
                chip
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.slot.prayer.displayName), \(row.status.label)")
    }

    private var chip: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(fill)
                Circle().strokeBorder(ringColor, style: StrokeStyle(lineWidth: isActive ? 2.5 : 1.5, dash: dashed ? [3, 3] : []))
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 50, height: 50)
            Text(row.slot.prayer.displayName)
                .font(.caption.weight(isActive ? .semibold : .regular))
                .foregroundStyle(row.status == .notTracked ? RukiPalette.secondaryText.opacity(0.5) : RukiPalette.primaryText)
        }
    }

    private var isDone: Bool { [.checkedInOnTime, .checkedInLate, .markedPrayed].contains(row.status) }
    private var dashed: Bool { row.status == .upcoming || row.status == .notTracked }

    private var fill: Color { isDone ? RukiPalette.accent : RukiPalette.background.opacity(0.6) }

    private var ringColor: Color {
        switch row.status {
        case .checkedInOnTime, .checkedInLate, .markedPrayed, .openOnTime, .openLate: RukiPalette.accent
        case .upcoming, .notTracked: RukiPalette.secondaryText.opacity(0.35)
        case .missed, .paused: RukiPalette.secondaryText.opacity(0.55)
        }
    }

    private var iconColor: Color {
        switch row.status {
        case .checkedInOnTime, .checkedInLate, .markedPrayed: RukiPalette.background
        case .openOnTime, .openLate: RukiPalette.accent
        case .upcoming, .notTracked: RukiPalette.secondaryText.opacity(0.5)
        case .missed, .paused: RukiPalette.secondaryText
        }
    }

    private var symbol: String {
        switch row.status {
        case .checkedInOnTime, .checkedInLate, .markedPrayed: "checkmark"
        case .paused: "pause.fill"
        default: row.slot.prayer.symbolName
        }
    }
}

extension Prayer {
    /// A sun-arc icon per prayer — the day's shape in five glyphs.
    var symbolName: String {
        switch self {
        case .fajr: "sunrise.fill"
        case .dhuhr: "sun.max.fill"
        case .asr: "sun.haze.fill"
        case .maghrib: "sunset.fill"
        case .isha: "moon.stars.fill"
        }
    }
}
