import Foundation
import Testing
@testable import Ruki

/// RUKI-014: what a tapped prompt opens depends on *when* it's tapped, not just
/// which prayer it was for. All times below are Toronto wall-clock on the frozen
/// 2026-09-19 schedule (Dhuhr 13:05, Asr 16:35, Isha 20:40, Fajr 05:20, D27).
@MainActor
@Suite("CheckInRouteResolver")
struct CheckInRouteResolverTests {
    private func at(_ isoWithOffset: String) -> Date {
        ISO8601DateFormatter().date(from: isoWithOffset)!
    }

    private func makeResolver(
        now: String,
        windowMinutes: Int = 30,
        store: HistoryStore? = nil
    ) throws -> (CheckInRouteResolver, HistoryStore) {
        let suite = "CheckInRouteResolverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = UserSettings(defaults: defaults)
        settings.checkInWindowMinutes = windowMinutes
        let historyStore = try store ?? HistoryStore(modelContainer: RukiModelContainer.make(inMemory: true))
        let resolver = CheckInRouteResolver(
            timeline: PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard),
            clock: FixedClock(date: at(now)),
            userSettings: settings,
            historyStore: historyStore,
            cameraProvider: FakeCameraProvider()
        )
        return (resolver, historyStore)
    }

    /// The flow's view model, or a recorded failure naming what came back instead.
    private func flow(_ route: CheckInRouteResolver.Route, sourceLocation: SourceLocation = #_sourceLocation) -> CheckInViewModel? {
        if case .flow(let viewModel) = route { return viewModel }
        Issue.record("Expected .flow, got \(route)", sourceLocation: sourceLocation)
        return nil
    }

    @Test("A prompt tapped inside the on-time window opens the flow, not marked late")
    func onTimeOpensTheFlow() throws {
        let (resolver, _) = try makeResolver(now: "2026-09-19T13:10:00-04:00")
        let viewModel = flow(resolver.route(forSlotID: "2026-09-19.dhuhr"))
        #expect(viewModel?.isLate == false)
        #expect(viewModel?.slot.prayer == .dhuhr)
        #expect(viewModel?.state == .affirm)
    }

    @Test("Tapped after the on-time window but before the prayer window closes: still opens, flagged late")
    func lateOpensTheFlowFlaggedLate() throws {
        let (resolver, _) = try makeResolver(now: "2026-09-19T13:50:00-04:00")
        #expect(flow(resolver.route(forSlotID: "2026-09-19.dhuhr"))?.isLate == true)
    }

    @Test("The user's shorter check-in window setting is honoured (D33)")
    func userWindowSettingIsHonoured() throws {
        let (thirty, _) = try makeResolver(now: "2026-09-19T13:20:00-04:00", windowMinutes: 30)
        let (ten, _) = try makeResolver(now: "2026-09-19T13:20:00-04:00", windowMinutes: 10)
        #expect(flow(thirty.route(forSlotID: "2026-09-19.dhuhr"))?.isLate == false)
        #expect(flow(ten.route(forSlotID: "2026-09-19.dhuhr"))?.isLate == true)
    }

    @Test("Fajr is never late before sunrise, whatever the window setting (D17)")
    func fajrIgnoresWindowSetting() throws {
        let (resolver, _) = try makeResolver(now: "2026-09-19T06:30:00-04:00", windowMinutes: 10)
        #expect(flow(resolver.route(forSlotID: "2026-09-19.fajr"))?.isLate == false)
    }

    @Test("Tapped after the window has ended: a plain note, never the camera")
    func closedWindowIsNotACheckIn() throws {
        let (resolver, _) = try makeResolver(now: "2026-09-19T16:40:00-04:00")
        guard case .windowClosed(let prayer) = resolver.route(forSlotID: "2026-09-19.dhuhr") else {
            Issue.record("Expected .windowClosed"); return
        }
        #expect(prayer == .dhuhr)
    }

    @Test("Tapped before the adhan has arrived")
    func upcomingWindowIsNotYetOpen() throws {
        let (resolver, _) = try makeResolver(now: "2026-09-19T12:00:00-04:00")
        guard case .notYetOpen(let prayer) = resolver.route(forSlotID: "2026-09-19.dhuhr") else {
            Issue.record("Expected .notYetOpen"); return
        }
        #expect(prayer == .dhuhr)
    }

    @Test("Already checked in from Today: the tap must not open the camera or overwrite it")
    func alreadyCheckedIn() throws {
        let (resolver, store) = try makeResolver(now: "2026-09-19T13:10:00-04:00")
        let slot = try #require(PrayerTimeline(provider: FixedPrayerTimeProvider(), madhab: .standard)
            .slots(onDayOf: at("2026-09-19T13:10:00-04:00")).first { $0.prayer == .dhuhr })
        try store.recordCheckIn(
            for: slot, isLate: false, checkedInAt: at("2026-09-19T13:08:00-04:00"),
            frontImageData: nil, rearImageData: Data([0x02]), expiresAt: slot.window.end
        )

        guard case .alreadyCheckedIn(let prayer) = resolver.route(forSlotID: slot.id) else {
            Issue.record("Expected .alreadyCheckedIn"); return
        }
        #expect(prayer == .dhuhr)
    }

    @Test("Isha's window runs past midnight (D30): tapped at 1 a.m., last night's Isha still opens")
    func ishaAfterMidnightStillOpens() throws {
        let (resolver, _) = try makeResolver(now: "2026-09-20T01:00:00-04:00")
        let viewModel = flow(resolver.route(forSlotID: "2026-09-19.isha"))
        #expect(viewModel?.slot.prayer == .isha)
        #expect(viewModel?.isLate == true)
    }

    @Test("An unrecognised slot id opens a note, not a crash")
    func unknownSlot() throws {
        let (resolver, _) = try makeResolver(now: "2026-09-19T13:10:00-04:00")
        for bad in ["", "garbage", "2026-09-19.notaprayer", "1999-01-01.fajr"] {
            guard case .unknown = resolver.route(forSlotID: bad) else {
                Issue.record("Expected .unknown for \(bad.debugDescription)"); continue
            }
        }
    }

    @Test("Space Only default carries into the flow")
    func spaceOnlyDefault() throws {
        let (resolver, _) = try makeResolver(now: "2026-09-19T13:10:00-04:00")
        // default is off => dual
        #expect(flow(resolver.route(forSlotID: "2026-09-19.dhuhr"))?.isSpaceOnly == false)
    }
}
