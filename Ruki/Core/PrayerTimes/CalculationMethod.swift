/// Astronomical convention used to derive Fajr/Isha twilight angles.
/// ISNA is the MVP default for Toronto pending OQ-8 (PRD §8.3, §8.4).
enum CalculationMethod: String, Codable, Sendable {
    case isna
    case muslimWorldLeague
}
