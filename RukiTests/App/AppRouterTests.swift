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

    @Test("Has no pending check-in until one is opened")
    func noPendingCheckInByDefault() {
        let router = AppRouter(userSettings: UserSettings(defaults: freshDefaults()))
        #expect(router.pendingCheckInSlotID == nil)
    }

    @Test("openCheckIn(forSlotID:) sets the pending slot, independent of destination")
    func openCheckInSetsPendingSlot() {
        let router = AppRouter(userSettings: UserSettings(defaults: freshDefaults()))

        router.openCheckIn(forSlotID: "2026-09-20.fajr")

        #expect(router.pendingCheckInSlotID == "2026-09-20.fajr")
        #expect(router.destination == .onboarding) // unaffected by the pending check-in
    }

    @Test("dismissCheckIn() clears the pending slot")
    func dismissCheckInClearsPendingSlot() {
        let router = AppRouter(userSettings: UserSettings(defaults: freshDefaults()))
        router.openCheckIn(forSlotID: "2026-09-20.fajr")

        router.dismissCheckIn()

        #expect(router.pendingCheckInSlotID == nil)
    }
}
