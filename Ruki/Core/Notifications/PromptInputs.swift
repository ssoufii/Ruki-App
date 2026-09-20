import Foundation

/// The subset of `UserSettings` that changes what gets scheduled, captured as
/// a `Sendable` value so a caller can read it once on the main actor (where
/// `UserSettings` lives) and then hand it to `PromptScheduler.refresh`
/// without carrying the `@MainActor` class across the boundary.
struct PromptInputs: Sendable, Equatable {
    let enabledPrayers: Set<Prayer>
    let soundEnabled: Bool
}

extension UserSettings {
    var promptInputs: PromptInputs {
        PromptInputs(enabledPrayers: enabledPrayers, soundEnabled: soundEnabled)
    }
}

extension PromptScheduler {
    func refresh(slots: [PrayerSlot], inputs: PromptInputs) async throws {
        try await refresh(slots: slots, enabledPrayers: inputs.enabledPrayers, soundEnabled: inputs.soundEnabled)
    }
}
