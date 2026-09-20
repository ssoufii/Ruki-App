import Foundation

/// One notification to schedule: a single prayer's adhan on a single day.
struct PromptSpec: Sendable, Equatable {
    /// Every identifier this app schedules starts with this, so a scheduler
    /// can find and clear exactly its own notifications and nothing else's.
    static let identifierPrefix = "ruki.prompt."

    let id: String
    let prayer: Prayer
    let fireDate: Date

    init(slot: PrayerSlot) {
        self.id = "\(Self.identifierPrefix)\(slot.id)"
        self.prayer = slot.prayer
        self.fireDate = slot.window.start
    }
}
