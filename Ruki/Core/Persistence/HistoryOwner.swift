import Foundation

/// Whose on-device history this is. Check-ins, private marks and pauses belong
/// to a person, not to a phone, so each account gets its own store and signed-out
/// use has its own (D48).
enum HistoryOwner: Sendable, Equatable {
    case guest
    case account(userID: String)

    var key: String {
        switch self {
        case .guest: "guest"
        case .account(let userID): "account-\(userID)"
        }
    }

    /// `nil` is the original default store, so anything recorded before accounts
    /// existed stays with the signed-out person instead of being orphaned.
    var storeName: String? {
        if case .account = self { key } else { nil }
    }
}
