import Testing
@testable import Ruki

@Suite("CheckInRules")
struct CheckInRulesTests {
    @Test("A short caption passes through unchanged")
    func shortCaptionPassesThrough() {
        #expect(CheckInRules.sanitizedCaption("Alhamdulillah") == "Alhamdulillah")
    }

    @Test("Leading and trailing whitespace/newlines are trimmed")
    func trimsWhitespace() {
        #expect(CheckInRules.sanitizedCaption("  \n Made it \n  ") == "Made it")
    }

    @Test("A caption over 80 characters is capped at 80")
    func capsAtEightyCharacters() {
        let raw = String(repeating: "a", count: 120)
        let sanitized = CheckInRules.sanitizedCaption(raw)
        #expect(sanitized?.count == CheckInRules.maxCaptionLength)
        #expect(sanitized == String(repeating: "a", count: 80))
    }

    @Test("Exactly 80 characters is left untouched")
    func exactlyEightyIsUntouched() {
        let raw = String(repeating: "a", count: 80)
        #expect(CheckInRules.sanitizedCaption(raw) == raw)
    }

    @Test("Empty or whitespace-only input becomes nil, not an empty string")
    func emptyOrWhitespaceBecomesNil() {
        #expect(CheckInRules.sanitizedCaption("") == nil)
        #expect(CheckInRules.sanitizedCaption("   \n\t  ") == nil)
    }
}
