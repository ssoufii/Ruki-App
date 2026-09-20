import SwiftData

/// The one SwiftData schema for the app. Kept in one place so the on-disk
/// container and every in-memory test container stay in sync.
enum RukiModelContainer {
    static let schema = Schema([CheckInRecord.self, PrayerMark.self, PauseRecord.self])

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
