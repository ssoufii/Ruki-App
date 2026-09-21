import Foundation
import os

/// A clock that runs at real speed but can be shifted to any instant.
///
/// Debug builds use it so a tester can jump to "Asr just began" or "Maghrib's
/// late phase" instead of waiting for the real adhan. It goes through
/// `ClockProviding` like everything else, so no feature code knows the
/// difference. Release builds use `SystemClock` directly.
final class OffsetClock: ClockProviding, Sendable {
    private let base: any ClockProviding
    private let offset = OSAllocatedUnfairLock<TimeInterval>(initialState: 0)
    private let anchor = OSAllocatedUnfairLock<Date?>(initialState: nil)

    init(base: any ClockProviding = SystemClock()) {
        self.base = base
    }

    nonisolated func now() -> Date {
        base.now().addingTimeInterval(offset.withLock { $0 })
    }

    /// The unshifted time. Debug jumps are measured from this, so repeated jumps
    /// land on the same instant instead of walking forward a day each time, and
    /// two accounts jumping to the same scenario end up on the same prayer.
    nonisolated func realNow() -> Date {
        base.now()
    }

    /// The real moment this test session's jumps are measured from, fixed at the
    /// first jump and kept until `reset()`. Without it, the "test day" would move
    /// on if real time crossed midnight mid-session and split an account's check-ins.
    nonisolated func testAnchor() -> Date {
        anchor.withLock { current in
            if let current { return current }
            let now = base.now()
            current = now
            return now
        }
    }

    nonisolated func jump(to target: Date) {
        let delta = target.timeIntervalSince(base.now())
        offset.withLock { $0 = delta }
    }

    nonisolated func reset() {
        offset.withLock { $0 = 0 }
        anchor.withLock { $0 = nil }
    }

    nonisolated var isShifted: Bool {
        offset.withLock { $0 != 0 }
    }
}
