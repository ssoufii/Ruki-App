import Testing
@testable import Ruki

@Suite("PrayerSlot.prayer(fromID:)")
struct PrayerSlotTests {
    @Test("Recovers the prayer from a well-formed slot id")
    func recoversPrayer() {
        #expect(PrayerSlot.prayer(fromID: "2026-09-20.fajr") == .fajr)
        #expect(PrayerSlot.prayer(fromID: "2026-09-20.maghrib") == .maghrib)
    }

    @Test("Returns nil for an id with no dot")
    func rejectsMissingDot() {
        #expect(PrayerSlot.prayer(fromID: "fajr") == nil)
    }

    @Test("Returns nil for an id whose suffix isn't a known prayer")
    func rejectsUnknownSuffix() {
        #expect(PrayerSlot.prayer(fromID: "2026-09-20.jumuah") == nil)
    }
}
