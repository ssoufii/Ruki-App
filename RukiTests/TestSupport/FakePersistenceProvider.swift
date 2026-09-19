import SwiftData
@testable import Ruki

/// In-memory SwiftData container for tests — never touches disk.
/// Empty schema is intentional: no concrete `@Model` types exist yet in M0
/// (see `PersistenceProviding`'s doc comment); this only proves the
/// container itself is fakeable.
struct FakePersistenceProvider: PersistenceProviding {
    let modelContainer: ModelContainer

    init() {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // Force-try is safe: an in-memory container can't fail to initialize.
        modelContainer = try! ModelContainer(for: Schema([]), configurations: configuration)
    }
}
