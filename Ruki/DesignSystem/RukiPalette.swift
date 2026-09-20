import SwiftUI

/// The app's base color tokens. Deliberately no red anywhere: CLAUDE.md's
/// tone rules and the Religious Design Principles rule out anything that
/// reads as an alarm or a failure state — a missed prayer is never styled
/// like an error.
///
/// State-specific colours (on-time/late/missed/paused) belong to the
/// calendar/history screens (RUKI-032), which must also carry those states
/// through shape and label, not colour alone — not defined here.
enum RukiPalette {
    static let background = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let surface = Color(red: 0.95, green: 0.91, blue: 0.84)
    static let primaryText = Color(red: 0.20, green: 0.16, blue: 0.12)
    static let secondaryText = Color(red: 0.45, green: 0.40, blue: 0.34)
    static let accent = Color(red: 0.62, green: 0.46, blue: 0.18)
}
