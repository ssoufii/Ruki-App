import Foundation

/// RUKI-014: decides what a tapped prompt should open.
///
/// A notification can be tapped long after it fired — after the window closed,
/// after the person already checked in from Today, or (for Isha, whose window
/// runs to the next Fajr) on the following calendar day. Sending every tap
/// straight into the camera flow would either overwrite an existing check-in or
/// offer one for a prayer that can no longer be checked in for, so the tap is
/// resolved against the *current* time first. Pure logic with no UI, so it can
/// be tested against any instant.
@MainActor
struct CheckInRouteResolver {
    enum Route {
        /// The real check-in flow, ready to start.
        case flow(CheckInViewModel)
        case alreadyCheckedIn(Prayer)
        /// The prayer window has ended. Only a private mark is possible now,
        /// and that lives on Today.
        case windowClosed(Prayer)
        case notYetOpen(Prayer)
        case unknown
    }

    let timeline: PrayerTimeline
    let clock: any ClockProviding
    let userSettings: UserSettings
    let historyStore: HistoryStore
    let cameraProvider: any CameraProviding

    func route(forSlotID slotID: String) -> Route {
        let now = clock.now()
        // Yesterday matters: Isha's window (D30) crosses midnight.
        let slot = [-1, 0, 1]
            .flatMap { timeline.slots(onDayOf: TorontoCalendar.startOfDay(byAdding: $0, to: now)) }
            .first { $0.id == slotID }
        guard let slot else { return .unknown }

        // If the read fails, fall through to the flow: `recordCheckIn` is the
        // real guard, and refusing a check-in over an unreadable store would be worse.
        if let existing = try? historyStore.checkInSnapshots(), existing.contains(where: { $0.slotID == slot.id }) {
            return .alreadyCheckedIn(slot.prayer)
        }

        switch timeline.phase(of: slot, at: now, userWindowMinutes: userSettings.checkInWindowMinutes) {
        case .upcoming:
            return .notYetOpen(slot.prayer)
        case .closed:
            return .windowClosed(slot.prayer)
        case .onTime, .late:
            let isLate = timeline.phase(of: slot, at: now, userWindowMinutes: userSettings.checkInWindowMinutes) == .late
            return .flow(CheckInViewModel(
                slot: slot,
                isLate: isLate,
                captureMode: userSettings.spaceOnlyDefault ? .spaceOnly : .dual,
                // Same lifetime rule as Today's own check-in doorway (D37).
                expiresAt: timeline.nextSlot(after: slot.window.start)?.window.start ?? slot.window.end,
                cameraProvider: cameraProvider,
                clock: clock,
                historyStore: historyStore
            ))
        }
    }
}
