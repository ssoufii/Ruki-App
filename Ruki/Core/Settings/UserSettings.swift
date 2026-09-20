import Foundation
import Observation

/// The user's own preferences, persisted across launches. `UserDefaults`-backed
/// rather than SwiftData: these are small scalars nothing else queries, unlike
/// the history records `HistoryStore` owns.
///
/// `@MainActor` because it's read and written from the UI (Settings, pause,
/// onboarding). Code that plans notifications from a background context
/// (background refresh, not yet built — RUKI-015) reads a `PromptInputs`
/// snapshot instead of holding this instance, so it never has to cross the
/// main actor to do its work.
@MainActor
@Observable
final class UserSettings {
    /// PRD §7.9 offers 10/15/30; this is the value before any prayer's own
    /// invariant (Maghrib ≤20, Fajr ignoring it — D33) is applied.
    static let defaultCheckInWindowMinutes = 30

    private let defaults: UserDefaults

    private enum Key {
        static let madhab = "settings.madhab"
        static let checkInWindowMinutes = "settings.checkInWindowMinutes"
        static let disabledPrayers = "settings.disabledPrayers"
        static let soundEnabled = "settings.soundEnabled"
        static let spaceOnlyDefault = "settings.spaceOnlyDefault"
        static let onboardingCompletedAt = "settings.onboardingCompletedAt"
    }

    var madhab: Madhab {
        didSet { defaults.set(madhab.rawValue, forKey: Key.madhab) }
    }

    var checkInWindowMinutes: Int {
        didSet { defaults.set(checkInWindowMinutes, forKey: Key.checkInWindowMinutes) }
    }

    /// Which prayers prompt the user (RUKI-017: Fajr can be disabled on its
    /// own). Stored as the *disabled* set so a fresh install — no key written
    /// yet — reads back as "everything enabled" with no migration needed.
    var enabledPrayers: Set<Prayer> {
        didSet {
            let disabled = Set(Prayer.allCases).subtracting(enabledPrayers)
            defaults.set(disabled.map(\.rawValue), forKey: Key.disabledPrayers)
        }
    }

    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) }
    }

    var spaceOnlyDefault: Bool {
        didSet { defaults.set(spaceOnlyDefault, forKey: Key.spaceOnlyDefault) }
    }

    var onboardingCompletedAt: Date? {
        didSet { defaults.set(onboardingCompletedAt, forKey: Key.onboardingCompletedAt) }
    }

    /// `defaults` is injectable so tests get an isolated store (a private
    /// suite) instead of polluting — or being polluted by — `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        madhab = Madhab(rawValue: defaults.string(forKey: Key.madhab) ?? "") ?? .standard

        let storedWindow = defaults.object(forKey: Key.checkInWindowMinutes) as? Int
        checkInWindowMinutes = storedWindow ?? Self.defaultCheckInWindowMinutes

        let disabledRaw = defaults.stringArray(forKey: Key.disabledPrayers) ?? []
        let disabled = Set(disabledRaw.compactMap(Prayer.init(rawValue:)))
        enabledPrayers = Set(Prayer.allCases).subtracting(disabled)

        soundEnabled = (defaults.object(forKey: Key.soundEnabled) as? Bool) ?? true
        spaceOnlyDefault = (defaults.object(forKey: Key.spaceOnlyDefault) as? Bool) ?? false
        onboardingCompletedAt = defaults.object(forKey: Key.onboardingCompletedAt) as? Date
    }

    /// RUKI-037: "Delete my data on this device" resets every preference to
    /// its fresh-install default. `onboardingCompletedAt` going back to
    /// `nil` is what sends `AppRouter` — which reads it live — back to
    /// onboarding; nothing else has to ask it to.
    func resetToDefaults() {
        madhab = .standard
        checkInWindowMinutes = Self.defaultCheckInWindowMinutes
        enabledPrayers = Set(Prayer.allCases)
        soundEnabled = true
        spaceOnlyDefault = false
        onboardingCompletedAt = nil
    }
}
