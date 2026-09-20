import SwiftData

/// The real `PersistenceProviding` used by the running app.
struct SwiftDataPersistence: PersistenceProviding {
    let modelContainer: ModelContainer

    init(inMemory: Bool = false) throws {
        modelContainer = try RukiModelContainer.make(inMemory: inMemory)
    }
}
