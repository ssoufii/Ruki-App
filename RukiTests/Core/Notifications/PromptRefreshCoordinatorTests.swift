import Foundation
import Testing
@testable import Ruki

@Suite("PromptRefreshCoordinator")
struct PromptRefreshCoordinatorTests {
    private let provider = FixedPrayerTimeProvider()

    /// A moment in Toronto local time on the reference day, well before
    /// Fajr (5:20 in the fixed provider), so "today" contributes all 5 slots.
    private var beforeFajr: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 19
        components.hour = 3
        return TorontoCalendar.calendar.date(from: components)!
    }

    /// Midway between Dhuhr (13:05) and Asr (16:35) on the same reference
    /// day, so Fajr and Dhuhr have already passed.
    private var betweenDhuhrAndAsr: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 19
        components.hour = 15
        return TorontoCalendar.calendar.date(from: components)!
    }

    private func makeCoordinator(now: Date, promptScheduler: PromptScheduler) -> PromptRefreshCoordinator {
        let timeline = PrayerTimeline(provider: provider, madhab: .standard)
        return PromptRefreshCoordinator(timeline: timeline, clock: FixedClock(date: now), promptScheduler: promptScheduler)
    }

    @Test("Exactly 12 calendar days of slots (60 = 12 × 5) when nothing today has passed yet (RUKI-015)")
    func exactlyTwelveDaysWhenNothingHasPassed() async throws {
        let fake = FakeNotificationScheduler()
        let sut = makeCoordinator(now: beforeFajr, promptScheduler: PromptScheduler(scheduler: fake))

        let slots = sut.upcomingSlots()

        #expect(slots.count == 60)
        let lastDayKey = TorontoCalendar.dayKey(for: TorontoCalendar.startOfDay(byAdding: 11, to: beforeFajr))
        #expect(slots.contains { $0.dayKey == lastDayKey && $0.prayer == .isha })
        let thirteenthDayKey = TorontoCalendar.dayKey(for: TorontoCalendar.startOfDay(byAdding: 12, to: beforeFajr))
        #expect(!slots.contains { $0.dayKey == thirteenthDayKey })
    }

    @Test("Already-passed prayers today are excluded, so a stale refresh can't re-request them")
    func excludesAlreadyPassedPrayersToday() async throws {
        let fake = FakeNotificationScheduler()
        let sut = makeCoordinator(now: betweenDhuhrAndAsr, promptScheduler: PromptScheduler(scheduler: fake))

        let slots = sut.upcomingSlots()
        let today = slots.filter { $0.dayKey == TorontoCalendar.dayKey(for: betweenDhuhrAndAsr) }

        #expect(Set(today.map(\.prayer)) == [.asr, .maghrib, .isha])
    }

    @Test("refresh(inputs:) hands the horizon to PromptScheduler, honouring enabledPrayers and soundEnabled")
    func refreshHandsHorizonToScheduler() async throws {
        let fake = FakeNotificationScheduler()
        let promptScheduler = PromptScheduler(scheduler: fake)
        let sut = makeCoordinator(now: beforeFajr, promptScheduler: promptScheduler)
        let inputs = PromptInputs(enabledPrayers: [.dhuhr, .asr, .maghrib, .isha], soundEnabled: false)

        try await sut.refresh(inputs: inputs)

        let scheduled = await fake.scheduled
        #expect(scheduled.count == 48) // 12 days × 4 enabled prayers
        #expect(!scheduled.contains { $0.prayer == .fajr })
        #expect(await fake.lastSoundEnabled == false)
    }
}
