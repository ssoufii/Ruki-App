/// Which Asr convention to use. Toronto's Muslim population is substantially
/// Hanafi, and the two can differ by 45+ minutes — both are required at MVP
/// (PRD §8.3).
enum Madhab: String, Codable, Sendable {
    /// Shafi'i / Maliki / Hanbali. Asr begins when an object's shadow equals its length.
    case standard
    /// Asr begins when an object's shadow equals twice its length.
    case hanafi
}
