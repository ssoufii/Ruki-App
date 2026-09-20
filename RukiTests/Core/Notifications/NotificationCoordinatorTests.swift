import Testing
@testable import Ruki

/// `UNNotificationResponse`/`UNNotificationRequest` have no public
/// initializer usable from a test host, so the delegate methods themselves
/// (`didReceive`/`willPresent`) can't be unit-tested — only exercised on a
/// device or in the Simulator's UI. What's testable, and tested here, is the
/// pure identifier-parsing logic those methods delegate to.
@Suite("NotificationCoordinator.slotID(fromRequestIdentifier:)")
struct NotificationCoordinatorTests {
    @Test("Strips the ruki.prompt. prefix to recover the slot id")
    func stripsPrefix() {
        let slotID = NotificationCoordinator.slotID(fromRequestIdentifier: "ruki.prompt.2026-09-20.fajr")
        #expect(slotID == "2026-09-20.fajr")
    }

    @Test("Returns nil for an identifier this app didn't schedule")
    func rejectsForeignIdentifier() {
        #expect(NotificationCoordinator.slotID(fromRequestIdentifier: "com.apple.something.else") == nil)
    }

    @Test("Returns nil for the bare prefix with nothing after it")
    func rejectsEmptySuffix() {
        #expect(NotificationCoordinator.slotID(fromRequestIdentifier: "ruki.prompt.") == nil)
    }
}
