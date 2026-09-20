/// Value-type view of a stored check-in, so history logic never touches SwiftData.
struct CheckInSnapshot: Sendable, Equatable {
    let slotID: String
    let isLate: Bool
}
