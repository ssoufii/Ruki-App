import Foundation
@testable import Ruki

/// Returns whatever windows a test hands it, ignoring the requested date/
/// madhab — for unit-testing consumers (scheduler, streak logic) in
/// isolation from real prayer-time computation.
struct StubPrayerTimeProvider: PrayerTimeProviding {
    var windows: [PrayerWindow]

    nonisolated func prayerWindows(for date: Date, madhab: Madhab) -> [PrayerWindow] {
        windows
    }
}
