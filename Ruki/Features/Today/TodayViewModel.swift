import Foundation
import Observation

/// Backs `TodayView`: today's five prayer rows, a current/next-prayer
/// headline with a gentle countdown, and which row (if any) is open right
/// now. Every computation takes `clock.now()` as its "now" — never `Date()`
/// (CLAUDE.md's no-`Date()` rule) — so DEBUG's `OffsetClock` and a real
/// device run identical logic.
@MainActor
@Observable
final class TodayViewModel {
    struct Row: Sendable, Equatable, Identifiable {
        enum Status: Sendable, Equatable {
            /// The adhan hasn't come yet.
            case upcoming
            /// Open, no check-in yet, still inside the on-time cutoff.
            case openOnTime
            /// Open, no check-in yet, past the on-time cutoff but still accepted.
            case openLate
            case checkedInOnTime
            case checkedInLate
            /// Privately marked prayed after the window closed (RUKI-026, counts).
            case markedPrayed
            /// Window closed with no check-in and no private mark. Neutral —
            /// never styled as a failure (CLAUDE.md Tone).
            case missed
            /// Covered by a pause (RDP-3): neither counted nor missed.
            case paused
            /// Began before the user completed onboarding; not part of their history.
            case notTracked

            var label: String {
                switch self {
                case .upcoming: String(localized: "Not open yet")
                case .openOnTime: String(localized: "Open — check in")
                case .openLate: String(localized: "Open — still counts")
                case .checkedInOnTime: String(localized: "Checked in")
                case .checkedInLate: String(localized: "Checked in late — still counts")
                case .markedPrayed: String(localized: "Marked prayed")
                case .missed: String(localized: "No check-in")
                case .paused: String(localized: "Paused")
                case .notTracked: String(localized: "Before you started using Ruki")
                }
            }

            /// SF Symbol per status, always paired with `label` — state is never
            /// carried by colour or icon alone (CLAUDE.md, PRD §7.7 calendar rule
            /// applied consistently here too).
            var symbolName: String {
                switch self {
                case .upcoming, .notTracked: "circle.dotted"
                case .openOnTime, .openLate: "circle"
                case .checkedInOnTime, .checkedInLate, .markedPrayed: "checkmark.circle.fill"
                case .missed: "circle"
                case .paused: "pause.circle"
                }
            }
        }

        let slot: PrayerSlot
        let status: Status
        var id: String { slot.id }
    }

    private let timeline: PrayerTimeline
    private let clock: any ClockProviding
    private let userSettings: UserSettings
    private let historyStore: HistoryStore

    private(set) var rows: [Row] = []
    private(set) var headline: String = ""
    private(set) var activeRow: Row?
    /// Whether a pause covers `clock.now()` right now (RDP-3). Drives
    /// whether the bottom bar's pause button offers to pause or to resume.
    private(set) var isPaused = false
    /// Surfaced rather than swallowed — a fetch failure means today's rows
    /// stay at their last-known state instead of silently going blank.
    private(set) var loadError: (any Error)?

    init(timeline: PrayerTimeline, clock: any ClockProviding, userSettings: UserSettings, historyStore: HistoryStore) {
        self.timeline = timeline
        self.clock = clock
        self.userSettings = userSettings
        self.historyStore = historyStore
    }

    /// Recomputes everything against `clock.now()`. Called on appear and on
    /// every minute tick so phase transitions and the countdown stay live
    /// without a pull-to-refresh.
    func refresh() {
        let now = clock.now()

        do {
            let pauses = try historyStore.pauseSnapshots()
            let resolver = SlotResolver(
                checkIns: try historyStore.checkInSnapshots(),
                marks: try historyStore.markSnapshots(),
                pauses: pauses,
                trackingStart: userSettings.onboardingCompletedAt ?? now
            )
            rows = timeline.slots(onDayOf: now).map { slot in
                Row(slot: slot, status: Self.status(for: slot, now: now, resolver: resolver, timeline: timeline, userSettings: userSettings))
            }
            isPaused = pauses.contains { $0.isActive(at: now) }
            loadError = nil
        } catch {
            loadError = error
        }

        activeRow = rows.first { $0.slot.window.start <= now && now < $0.slot.window.end }
        headline = Self.headlineText(now: now, timeline: timeline, userSettings: userSettings)
    }

    /// RUKI-026: privately marks a closed, unrecorded window as prayed or
    /// not. On-device only (RDP-2) — `HistoryStore.recordMark` never
    /// produces a network event, whichever way the user answers.
    func mark(_ row: Row, as kind: MarkSnapshot.Kind) {
        do {
            try historyStore.recordMark(for: row.slot, kind: kind, markedAt: clock.now())
            refresh()
        } catch {
            loadError = error
        }
    }

    /// RUKI-020: builds the check-in flow for an open row. `expiresAt` is the
    /// next slot's start (D26/D37, when the photo gets purged), and capture
    /// mode follows the user's Space Only default (RUKI-022 adds a
    /// per-capture override in the flow itself).
    func makeCheckInViewModel(for row: Row, cameraProvider: any CameraProviding, publisher: (any CheckInPublishing)? = nil) -> CheckInViewModel {
        CheckInViewModel(
            slot: row.slot,
            isLate: row.status == .openLate,
            captureMode: userSettings.spaceOnlyDefault ? .spaceOnly : .dual,
            expiresAt: timeline.nextSlot(after: row.slot.window.start)?.window.start ?? row.slot.window.end,
            cameraProvider: cameraProvider,
            clock: clock,
            historyStore: historyStore,
            publisher: publisher,
            onTimeUntil: timeline.onTimeEnd(of: row.slot.window, userWindowMinutes: userSettings.checkInWindowMinutes)
        )
    }

    /// RDP-3: "you can turn it back on anytime" — ends whatever pause is
    /// active right now, immediately, with no confirmation step, matching
    /// pause's own no-friction ethos. The caller re-plans notifications the
    /// same way `pause(for:)` expects.
    func resume() {
        do {
            try historyStore.resumeActivePause(now: clock.now())
            refresh()
        } catch {
            loadError = error
        }
    }

    /// RUKI-034: pauses starting now, for the chosen duration. The caller is
    /// responsible for re-planning notifications afterward (`AppEnvironment
    /// .refreshBackgroundSchedule`) — this type only owns `HistoryStore`.
    func pause(for duration: PauseDuration) {
        let now = clock.now()
        do {
            try historyStore.recordPause(startedAt: now, endsAt: duration.endsAt(from: now))
            refresh()
        } catch {
            loadError = error
        }
    }

    private static func status(
        for slot: PrayerSlot,
        now: Date,
        resolver: SlotResolver,
        timeline: PrayerTimeline,
        userSettings: UserSettings
    ) -> Row.Status {
        switch resolver.outcome(for: slot, now: now) {
        case .onTime: return .checkedInOnTime
        case .late: return .checkedInLate
        case .markedPrayed: return .markedPrayed
        case .missed: return .missed
        case .paused: return .paused
        case .notTracked: return .notTracked
        case .pending:
            switch timeline.phase(of: slot, at: now, userWindowMinutes: userSettings.checkInWindowMinutes) {
            case .upcoming: return .upcoming
            case .onTime: return .openOnTime
            case .late: return .openLate
            case .closed: return .missed
            }
        }
    }

    private static func headlineText(now: Date, timeline: PrayerTimeline, userSettings: UserSettings) -> String {
        if let active = timeline.activeSlot(at: now) {
            let phase = timeline.phase(of: active, at: now, userWindowMinutes: userSettings.checkInWindowMinutes)
            let deadline = phase == .onTime
                ? timeline.onTimeEnd(of: active.window, userWindowMinutes: userSettings.checkInWindowMinutes)
                : active.window.end
            let remaining = minutesText(from: now, to: deadline)
            return phase == .onTime
                ? String(localized: "\(active.prayer.displayName) is open — \(remaining) left to check in on time")
                : String(localized: "\(active.prayer.displayName) is open — \(remaining) left, still counts if you check in now")
        }
        guard let next = timeline.nextSlot(after: now) else {
            return String(localized: "No prayers scheduled")
        }
        return String(localized: "Next: \(next.prayer.displayName) in \(minutesText(from: now, to: next.window.start))")
    }

    private static func minutesText(from now: Date, to date: Date) -> String {
        let totalMinutes = max(0, Int(date.timeIntervalSince(now) / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        guard hours > 0 else { return String(localized: "\(minutes)m") }
        return String(localized: "\(hours)h \(minutes)m")
    }
}
