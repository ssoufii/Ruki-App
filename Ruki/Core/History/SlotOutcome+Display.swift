import Foundation

extension SlotOutcome {
    /// User-facing label for the history calendar (RUKI-032). Same tone rule
    /// as `TodayViewModel.Row.Status.label`: no red, no "FAILED", late and
    /// marked-prayed both read as counting, not as a lesser check-in.
    var calendarLabel: String {
        switch self {
        case .onTime: String(localized: "On time")
        case .late: String(localized: "Late — still counts")
        case .markedPrayed: String(localized: "Marked prayed")
        case .missed: String(localized: "No check-in")
        case .paused: String(localized: "Paused")
        case .pending: String(localized: "Open")
        case .notTracked: String(localized: "Before you started using Ruki")
        }
    }

    /// SF Symbol per outcome, always paired with `calendarLabel` — a calendar
    /// cell's state is never carried by colour alone (PRD §7.7: "paused is
    /// visually distinct from missed"; CLAUDE.md tone rules go further and
    /// keep colour out of state entirely, matching `TodayView`'s own rows).
    var calendarSymbolName: String {
        switch self {
        case .onTime: "checkmark.circle.fill"
        case .late: "checkmark.circle"
        case .markedPrayed: "checkmark.seal.fill"
        case .missed: "circle"
        case .paused: "pause.circle"
        case .pending: "circle.dotted"
        case .notTracked: "minus.circle"
        }
    }
}
