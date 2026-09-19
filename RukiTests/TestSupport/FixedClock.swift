import Foundation
@testable import Ruki

/// A clock pinned to a single instant, for deterministic time-based tests
/// (DST boundaries, solstices, midnight rollovers, clock-tampering scenarios).
struct FixedClock: ClockProviding {
    let date: Date

    nonisolated func now() -> Date {
        date
    }
}
