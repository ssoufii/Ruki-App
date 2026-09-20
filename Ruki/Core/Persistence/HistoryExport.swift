import Foundation

/// A local JSON export of everything `HistoryStore` holds, minus photo data
/// (D37: export excludes photos — the record that you prayed is the point,
/// not the picture). Never leaves the device except when the user
/// explicitly shares this file themselves (RUKI-037).
struct HistoryExport: Codable, Sendable, Equatable {
    struct CheckIn: Codable, Sendable, Equatable {
        let slotID: String
        let prayer: String
        let dayKey: String
        let isLate: Bool
        let checkedInAt: Date
        let caption: String?
    }

    struct Mark: Codable, Sendable, Equatable {
        let slotID: String
        let kind: String
        let markedAt: Date
    }

    struct Pause: Codable, Sendable, Equatable {
        let startedAt: Date
        let endsAt: Date?
    }

    let exportedAt: Date
    let checkIns: [CheckIn]
    let marks: [Mark]
    let pauses: [Pause]
}
