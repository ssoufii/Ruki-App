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

    init(base: any ClockProviding = SystemClock()) {
        self.base = base
    }

    nonisolated func now() -> Date {
        base.now().addingTimeInterval(offset.withLock { $0 })
    }

    nonisolated func jump(to target: Date) {
        let delta = target.timeIntervalSince(base.now())
        offset.withLock { $0 = delta }
    }

    nonisolated func reset() {
        offset.withLock { $0 = 0 }
    }

    nonisolated var isShifted: Bool {
        offset.withLock { $0 != 0 }
    }
}
