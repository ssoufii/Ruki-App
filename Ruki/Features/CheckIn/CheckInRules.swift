import Foundation

/// RUKI-023: the one rule governing captions — optional, trimmed, capped at
/// 80 characters. Pure so it's testable without any UI or storage.
enum CheckInRules {
    static let maxCaptionLength = 80

    /// Trims leading/trailing whitespace and newlines, then caps length.
    /// Empty after trimming becomes `nil` — there's no meaningful difference
    /// between "no caption" and "typed only spaces".
    nonisolated static func sanitizedCaption(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxCaptionLength))
    }
}
