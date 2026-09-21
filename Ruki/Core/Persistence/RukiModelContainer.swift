import SwiftData

/// The one SwiftData schema for the app. Kept in one place so the on-disk
/// container and every in-memory test container stay in sync.
enum RukiModelContainer {
    // Computed, not a stored `static let`: `Schema` isn't `Sendable`, so a
    // shared stored instance isn't concurrency-safe under Swift 6 strict
    // checking. Building a fresh one per call has no measurable cost here.
    static var schema: Schema {
        Schema([CheckInRecord.self, PrayerMark.self, PauseRecord.self])
    }

    /// `storeName` nil is the original default store; a name gives that account
    /// its own file (`HistoryStores`).
    static func make(inMemory: Bool = false, storeName: String? = nil) throws -> ModelContainer {
        let configuration = storeName.map { ModelConfiguration($0, schema: schema, isStoredInMemoryOnly: inMemory) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
