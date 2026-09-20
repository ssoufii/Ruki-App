import Foundation
import SwiftData

/// One pause (RDP-3). `endsAt == nil` means "until I turn it back on". A
/// user may have many of these over time; none is ever part of a
/// friend-facing payload (RUKI-035).
@Model
final class PauseRecord {
    var startedAt: Date
    var endsAt: Date?

    init(startedAt: Date, endsAt: Date?) {
        self.startedAt = startedAt
        self.endsAt = endsAt
    }
}
