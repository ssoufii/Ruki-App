import Foundation
import Testing
@testable import Ruki

@MainActor
@Suite("AppRouter")
struct AppRouterTests {
    private func freshDefaults() -> UserDefaults {
        let suiteName = "AppRouterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("Routes to onboarding when onboarding hasn't been completed")
    func routesToOnboardingByDefault() {
        let settings = UserSettings(defaults: freshDefaults())
        let router = AppRouter(userSettings: settings)
        #expect(router.destination == .onboarding)
    }

    @Test("Routes to today once onboarding has been completed")
    func routesToTodayOnceOnboarded() {
        let settings = UserSettings(defaults: freshDefaults())
        let router = AppRouter(userSettings: settings)

        settings.onboardingCompletedAt = ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z")!

        #expect(router.destination == .today)
    }

    @Test("Reads userSettings live, not a snapshot captured at init")
    func readsSettingsLiveRatherThanSnapshotting() {
        let settings = UserSettings(defaults: freshDefaults())
        settings.onboardingCompletedAt = ISO8601DateFormatter().date(from: "2026-09-20T12:00:00Z")!
        let router = AppRouter(userSettings: settings)
        #expect(router.destination == .today)

        settings.onboardingCompletedAt = nil
        #expect(router.destination == .onboarding)
    }
}
