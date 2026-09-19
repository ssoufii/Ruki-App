import Foundation

/// The real clock. This is the only type in the app permitted to call `Date()`.
struct SystemClock: ClockProviding {
    nonisolated func now() -> Date {
        Date() // swiftlint:disable:this no-direct-date — this is ClockProviding's own implementation
    }
}
