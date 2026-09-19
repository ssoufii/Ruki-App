/// The five daily obligatory prayers. Jumu'ah (Friday Dhuhr) is handled as a
/// display/logging distinction on top of `.dhuhr`, not a separate case here —
/// see PRD §7.10 (fast-follow) before adding Jumu'ah-specific engine logic.
enum Prayer: String, CaseIterable, Codable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha
}
