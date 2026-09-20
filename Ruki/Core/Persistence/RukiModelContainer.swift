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

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
