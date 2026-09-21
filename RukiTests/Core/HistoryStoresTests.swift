import Foundation
import Testing
@testable import Ruki

/// D48: two accounts on one device must never see or overwrite each other's
/// check-ins, marks or pauses.
@MainActor
@Suite("Per-account history (D48)")
struct HistoryStoresTests {
    private let now = ISO8601DateFormatter().date(from: "2026-09-19T13:10:00-04:00")!
    private let timeline = PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard)

    private func stores(defaults: UserDefaults? = nil) throws -> HistoryStores {
        HistoryStores(
            guestContainer: try RukiModelContainer.make(inMemory: true),
            defaults: defaults ?? UserDefaults(suiteName: UUID().uuidString)!,
            inMemory: true
        )
    }

    private func checkIn(_ store: HistoryStore, _ prayer: Prayer) throws {
        let slot = try #require(timeline.slots(onDayOf: now).first { $0.prayer == prayer })
        try store.recordCheckIn(
            for: slot, isLate: false, checkedInAt: now, frontImageData: nil,
            rearImageData: Data([1]), expiresAt: now.addingTimeInterval(3600)
        )
    }

    @Test("Sumeya's Fajr is not zenah's Fajr — each account's check-ins are its own")
    func accountsDoNotShareCheckIns() throws {
        let stores = try stores()
        let zenah = stores.store(for: .account(userID: "zenah"), now: now)
        let sumeya = stores.store(for: .account(userID: "sumeya"), now: now)

        try checkIn(zenah, .fajr)
        #expect(try zenah.checkInSnapshots().count == 1)
        #expect(try sumeya.checkInSnapshots().isEmpty, "sumeya must not inherit zenah's Fajr")

        try checkIn(sumeya, .fajr)      // and she can check in for the same prayer herself
        try checkIn(sumeya, .dhuhr)
        #expect(try sumeya.checkInSnapshots().count == 2)
        #expect(try zenah.checkInSnapshots().count == 1)
    }

    @Test("Signed-out use is its own history too, and marks and pauses stay separate")
    func guestAndAccountAreSeparate() throws {
        let stores = try stores()
        let guest = stores.store(for: .guest, now: now)
        let account = stores.store(for: .account(userID: "a"), now: now)
        try checkIn(guest, .asr)
        try account.recordPause(startedAt: now, endsAt: nil)
        #expect(try account.checkInSnapshots().isEmpty)
        #expect(try guest.pauseSnapshots().isEmpty, "a pause is private to the account that made it")
    }

    @Test("The same owner always gets the same store")
    func sameOwnerSameStore() throws {
        let stores = try stores()
        #expect(stores.store(for: .account(userID: "a"), now: now) === stores.store(for: .account(userID: "a"), now: now))
        #expect(stores.store(for: .guest, now: now) !== stores.store(for: .account(userID: "a"), now: now))
    }

    @Test("An account's start date is set once, on first use, and is its own")
    func trackingStartIsPerAccountAndStable() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let later = now.addingTimeInterval(3600)
        let first = try stores(defaults: defaults)
        #expect(first.store(for: .account(userID: "a"), now: now).trackingStart == now)
        #expect(first.store(for: .account(userID: "b"), now: later).trackingStart == later)
        #expect(first.store(for: .guest, now: now).trackingStart == nil)

        // A relaunch, much later, keeps the original date.
        let relaunched = try stores(defaults: defaults)
        #expect(relaunched.store(for: .account(userID: "a"), now: later.addingTimeInterval(86_400)).trackingStart == now)
    }

    @Test("A start date recorded from a jumped (future) clock is pulled back to real time")
    func futureTrackingStartIsClamped() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        _ = try stores(defaults: defaults).store(for: .account(userID: "a"), now: now.addingTimeInterval(5 * 86_400))
        #expect(try stores(defaults: defaults).store(for: .account(userID: "a"), now: now).trackingStart == now)
    }

    @Test("Device-wide jobs reach every account's store, including ones not logged in")
    func allStoresCoversEveryAccount() throws {
        let stores = try stores()
        _ = stores.store(for: .account(userID: "a"), now: now)
        _ = stores.store(for: .account(userID: "b"), now: now)
        #expect(stores.allStores(now: now).count == 3)   // signed-out + two accounts
    }

    @Test("Logging out and back in shows the same history")
    func historySurvivesLogOutAndIn() throws {
        let stores = try stores()
        try checkIn(stores.store(for: .account(userID: "sumeya"), now: now), .fajr)
        _ = stores.store(for: .account(userID: "zenah"), now: now)     // someone else logs in meanwhile
        _ = stores.store(for: .guest, now: now)                        // and someone uses the app signed out
        #expect(try stores.store(for: .account(userID: "sumeya"), now: now).checkInSnapshots().count == 1)
    }

    @Test("On disk: an account's history is still there after the app is relaunched")
    func historySurvivesRelaunchOnDisk() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let userID = "relaunch-\(UUID().uuidString)"
        var firstLaunch: HistoryStores? = HistoryStores(
            guestContainer: try RukiModelContainer.make(inMemory: true), defaults: defaults, inMemory: false
        )
        try checkIn(try #require(firstLaunch).store(for: .account(userID: userID), now: now), .fajr)
        firstLaunch = nil   // the app quits

        let secondLaunch = HistoryStores(
            guestContainer: try RukiModelContainer.make(inMemory: true), defaults: defaults, inMemory: false
        )
        let store = secondLaunch.store(for: .account(userID: userID), now: now)
        #expect(try store.checkInSnapshots().count == 1)
        try store.deleteAll()   // leave no test data behind in the simulator
    }
}
