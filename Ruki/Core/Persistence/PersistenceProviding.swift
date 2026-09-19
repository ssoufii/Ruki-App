import SwiftData

/// Boundary around SwiftData so call sites depend on a protocol, not a
/// concrete `ModelContainer`, and tests can swap in an in-memory container.
///
/// Kept deliberately minimal here in M0: concrete model types (`CheckIn`,
/// `MissedRecord`, `PauseRecord`, per PRD §10.3) land with their owning
/// features in M1, not before they're needed.
protocol PersistenceProviding: Sendable {
    var modelContainer: ModelContainer { get }
}
