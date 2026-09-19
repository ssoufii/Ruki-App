import Foundation

/// The single source of "now" for the entire app.
///
/// `Date()` must never be called directly in feature code — every serious bug
/// in this product is a time bug, and untestable time logic means unfindable
/// bugs. Inject this protocol instead so tests can pin time to any instant
/// (a DST boundary, a solstice, a midnight rollover) deterministically.
protocol ClockProviding: Sendable {
    nonisolated func now() -> Date
}
