import SwiftUI

/// The grid itself (PRD §7.7): one row per prayer, one column per day. Wrapped
/// in its own horizontal scroll so a 30-day window doesn't force the whole
/// screen to scroll sideways.
struct CalendarGridView: View {
    let grid: CalendarGrid

    private static let labelColumnWidth: CGFloat = 56

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Color.clear.frame(width: Self.labelColumnWidth, height: 1)
                    ForEach(grid.days) { day in
                        Text(Self.dayLabel(for: day.date))
                            .font(.caption2)
                            .foregroundStyle(RukiPalette.secondaryText)
                    }
                }
                ForEach(CalendarGrid.prayerOrder, id: \.self) { prayer in
                    GridRow {
                        Text(prayer.displayName)
                            .font(.caption)
                            .foregroundStyle(RukiPalette.primaryText)
                            .frame(width: Self.labelColumnWidth, alignment: .leading)
                        ForEach(grid.days) { day in
                            cell(for: prayer, on: day)
                        }
                    }
                }
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func cell(for prayer: Prayer, on day: CalendarGrid.Day) -> some View {
        if let cell = day.cells[prayer] {
            // Shape (the symbol) and the accessibility label carry the state;
            // colour never does (PRD §7.7's "paused is visually distinct from
            // missed" rule, applied the same way `TodayView`'s rows do it).
            Image(systemName: cell.outcome.calendarSymbolName)
                .imageScale(.small)
                .foregroundStyle(RukiPalette.secondaryText)
                .frame(width: 20, height: 20)
                .accessibilityLabel(
                    "\(prayer.displayName), \(Self.dayLabel(for: day.date)): \(cell.outcome.calendarLabel)"
                )
        } else {
            Color.clear.frame(width: 20, height: 20)
        }
    }

    // A fresh `DateFormatter` per call, not a shared static one:
    // `DateFormatter` isn't `Sendable` (same reasoning as
    // `StreakSummaryPresenter.timeText`).
    private static func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.timeZone = TorontoCalendar.timeZone
        return formatter.string(from: date)
    }
}
