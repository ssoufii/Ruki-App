import Foundation
import Testing
@testable import Ruki

@MainActor
@Suite("UserSettings")
struct UserSettingsTests {
    /// A private, uniquely-named suite per test so nothing here touches (or
    /// is affected by) `.standard`, and tests can't leak into each other.
    private func freshDefaults() -> UserDefaults {
        let suiteName = "UserSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("A fresh install has every prayer enabled, default window, sound on, Space Only off, no onboarding date")
    func freshInstallDefaults() {
        let settings = UserSettings(defaults: freshDefaults())
        #expect(settings.enabledPrayers == Set(Prayer.allCases))
        #expect(settings.checkInWindowMinutes == UserSettings.defaultCheckInWindowMinutes)
        #expect(settings.madhab == .standard)
        #expect(settings.soundEnabled == true)
        #expect(settings.spaceOnlyDefault == false)
        #expect(settings.onboardingCompletedAt == nil)
    }

    @Test("Disabling Fajr independently persists across a new instance backed by the same store (RUKI-017)")
    func disablingFajrPersists() {
        let defaults = freshDefaults()
        let settings = UserSettings(defaults: defaults)

        settings.enabledPrayers.remove(.fajr)

        let reloaded = UserSettings(defaults: defaults)
        #expect(reloaded.enabledPrayers == Set([.dhuhr, .asr, .maghrib, .isha]))
    }

    @Test("Disabling Fajr leaves the other four untouched")
    func disablingFajrDoesNotAffectOtherPrayers() {
        let settings = UserSettings(defaults: freshDefaults())
        settings.enabledPrayers.remove(.fajr)
        #expect(settings.enabledPrayers.contains(.dhuhr))
        #expect(settings.enabledPrayers.contains(.asr))
        #expect(settings.enabledPrayers.contains(.maghrib))
        #expect(settings.enabledPrayers.contains(.isha))
    }

    @Test("Re-enabling a disabled prayer persists too — the store isn't append-only")
    func reEnablingPersists() {
        let defaults = freshDefaults()
        let settings = UserSettings(defaults: defaults)

        settings.enabledPrayers.remove(.fajr)
        settings.enabledPrayers.insert(.fajr)

        let reloaded = UserSettings(defaults: defaults)
        #expect(reloaded.enabledPrayers == Set(Prayer.allCases))
    }

    @Test("Every other field round-trips through a new instance backed by the same store")
    func everyFieldRoundTrips() {
        let defaults = freshDefaults()
        let settings = UserSettings(defaults: defaults)
        let onboardingDate = ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z")!

        settings.madhab = .hanafi
        settings.checkInWindowMinutes = 15
        settings.soundEnabled = false
        settings.spaceOnlyDefault = true
        settings.onboardingCompletedAt = onboardingDate

        let reloaded = UserSettings(defaults: defaults)
        #expect(reloaded.madhab == .hanafi)
        #expect(reloaded.checkInWindowMinutes == 15)
        #expect(reloaded.soundEnabled == false)
        #expect(reloaded.spaceOnlyDefault == true)
        #expect(reloaded.onboardingCompletedAt == onboardingDate)
    }

    @Test("promptInputs mirrors enabledPrayers and soundEnabled, nothing else")
    func promptInputsMirrorsRelevantFields() {
        let settings = UserSettings(defaults: freshDefaults())
        settings.enabledPrayers.remove(.fajr)
        settings.soundEnabled = false

        let inputs = settings.promptInputs
        #expect(inputs.enabledPrayers == settings.enabledPrayers)
        #expect(inputs.soundEnabled == false)
    }
}
