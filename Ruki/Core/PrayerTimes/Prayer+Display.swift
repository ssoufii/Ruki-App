import Foundation

extension Prayer {
    /// User-facing name. Goes through String(localized:) so it's in the String Catalog.
    nonisolated var displayName: String {
        switch self {
        case .fajr: String(localized: "Fajr")
        case .dhuhr: String(localized: "Dhuhr")
        case .asr: String(localized: "Asr")
        case .maghrib: String(localized: "Maghrib")
        case .isha: String(localized: "Isha")
        }
    }
}
