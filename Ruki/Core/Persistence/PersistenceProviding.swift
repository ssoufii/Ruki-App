import SwiftData

/// Boundary around SwiftData so call sites depend on a protocol, not a
/// concrete `ModelContainer`, and tests can swap in an in-memory container.
protocol PersistenceProviding: Sendable {
    var modelContainer: ModelContainer { get }
}
