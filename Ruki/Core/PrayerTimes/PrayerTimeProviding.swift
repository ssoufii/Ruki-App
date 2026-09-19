import Foundation

/// Everything the app needs to know about prayer timing sits behind this
/// protocol so the source (fixed snapshot, cached AlAdhan schedule, on-device
/// Adhan-Swift fallback, or a test fake) is swappable without touching a
/// single call site (PRD §8.2, §10.1).
///
/// MVP note: `Ruki-App` GitHub Epic 02 conforms this to a frozen, hand-captured
/// snapshot (`FixedPrayerTimeProvider`) rather than a live engine — see that
/// type's documentation and MEMORY.md decision D27. Epic 13 replaces it.
protocol PrayerTimeProviding: Sendable {
    /// All five prayer windows for the calendar day containing `date`, in the
    /// given madhab. Ordered `.fajr, .dhuhr, .asr, .maghrib, .isha`.
    nonisolated func prayerWindows(for date: Date, madhab: Madhab) -> [PrayerWindow]
}
