import SwiftData
@testable import Ruki

/// In-memory SwiftData container for tests — never touches disk.
struct FakePersistenceProvider: PersistenceProviding {
    let modelContainer: ModelContainer

    init() {
        // Force-try is safe: an in-memory container against the app's own
        // schema can't fail to initialize.
        modelContainer = try! RukiModelContainer.make(inMemory: true)
    }
}
