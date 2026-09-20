import SwiftUI

/// RUKI-032: the History tab. Everything here is visible only to the user
/// (PRD §7.7) — there is no sharing mechanism and there must never be one.
struct CalendarView: View {
    @State private var viewModel: CalendarViewModel

    init(timeline: PrayerTimeline, clock: any ClockProviding, userSettings: UserSettings, historyStore: HistoryStore) {
        _viewModel = State(
            wrappedValue: CalendarViewModel(timeline: timeline, clock: clock, userSettings: userSettings, historyStore: historyStore)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                streakHeader

                CalendarGridView(grid: viewModel.grid)
                    .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 16))

                breakdownSection
            }
            .padding()
        }
        .background(RukiPalette.background)
        .navigationTitle(Text("History"))
        .task { viewModel.refresh() }
    }

    private var streakHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.streakHeadline)
                .font(.title2)
                .foregroundStyle(RukiPalette.primaryText)
            Text(viewModel.lifetimeText)
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)
            if let rateText = viewModel.thirtyDayRateText {
                Text(rateText)
                    .font(.subheadline)
                    .foregroundStyle(RukiPalette.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By prayer")
                .font(.headline)
                .foregroundStyle(RukiPalette.primaryText)
            VStack(spacing: 0) {
                ForEach(viewModel.breakdown) { row in
                    if row.id != viewModel.breakdown.first?.id {
                        Divider()
                    }
                    PrayerBreakdownRow(breakdown: row)
                }
            }
            .background(RukiPalette.surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct PrayerBreakdownRow: View {
    let breakdown: PrayerBreakdown

    var body: some View {
        HStack {
            Text(breakdown.prayer.displayName)
                .font(.body)
                .foregroundStyle(RukiPalette.primaryText)
            Spacer()
            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(RukiPalette.secondaryText)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    // Marked-prayed folds into "on time" here rather than getting its own
    // clause: both count identically toward the streak (PRD §7.7), and a
    // three-way breakdown per prayer reads clearer than four.
    private var summaryText: String {
        let countedOnTime = breakdown.onTimeCount + breakdown.markedPrayedCount
        return String(
            localized: "\(countedOnTime) on time, \(breakdown.lateCount) late, \(breakdown.missedCount) no check-in"
        )
    }
}

#Preview {
    let environment = AppEnvironment()
    return NavigationStack {
        CalendarView(
            timeline: environment.timeline,
            clock: environment.clock,
            userSettings: environment.userSettings,
            historyStore: environment.historyStore
        )
    }
}
