/// Value-type view of a private "prayed"/"missed" mark on a closed window (RUKI-026).
struct MarkSnapshot: Sendable, Equatable {
    enum Kind: String, Sendable {
        case prayed
        case missed
    }

    let slotID: String
    let kind: Kind
}
