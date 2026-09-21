import Foundation
import SwiftData

/// Hands out one `HistoryStore` per owner and keeps them apart: nothing an
/// account checks in, marks or pauses is visible to another account on the
/// same device (D48). Also owns each account's "started using Ruki" moment,
/// because prayers from before that account existed aren't its to miss.
@MainActor
final class HistoryStores {
    private let defaults: UserDefaults
    private let guestContainer: ModelContainer
    private let inMemory: Bool
    private var opened: [String: (container: ModelContainer, store: HistoryStore)] = [:]

    private enum Keys {
        static let knownAccounts = "history.knownAccountIDs"
        static func trackingStart(_ userID: String) -> String { "history.trackingStart.\(userID)" }
    }

    init(guestContainer: ModelContainer, defaults: UserDefaults = .standard, inMemory: Bool = false) {
        self.guestContainer = guestContainer
        self.defaults = defaults
        self.inMemory = inMemory
    }

    /// The same instance every time for the same owner, so open screens and the
    /// check-in flow always write to the store the person is looking at.
    func store(for owner: HistoryOwner, now: Date) -> HistoryStore {
        if let existing = opened[owner.key] { return existing.store }

        let container: ModelContainer
        let trackingStart: Date?
        switch owner {
        case .guest:
            container = guestContainer
            trackingStart = nil   // falls back to the device's onboarding date
        case .account(let userID):
            // In-memory is the honest fallback if the file can't be opened, as for the guest store.
            container = (try? RukiModelContainer.make(inMemory: inMemory, storeName: owner.storeName))
                ?? (try! RukiModelContainer.make(inMemory: true))   // in-memory with the app's own schema has no realistic failure
            trackingStart = recordedTrackingStart(for: userID, now: now)
            remember(userID)
        }
        let store = HistoryStore(modelContainer: container, trackingStart: trackingStart)
        opened[owner.key] = (container, store)
        return store
    }

    /// Every store on this device: signed-out plus each account that has ever
    /// been used here. For device-wide jobs (photo expiry, "delete my data").
    func allStores(now: Date) -> [HistoryStore] {
        [store(for: .guest, now: now)] + knownAccountIDs.map { store(for: .account(userID: $0), now: now) }
    }

    // MARK: Private

    private var knownAccountIDs: [String] {
        defaults.stringArray(forKey: Keys.knownAccounts) ?? []
    }

    private func remember(_ userID: String) {
        var ids = knownAccountIDs
        if !ids.contains(userID) { ids.append(userID) }
        defaults.set(ids, forKey: Keys.knownAccounts)
    }

    /// Set once, the first time this account is used on this device.
    private func recordedTrackingStart(for userID: String, now: Date) -> Date {
        if let saved = defaults.object(forKey: Keys.trackingStart(userID)) as? Date { return saved }
        defaults.set(now, forKey: Keys.trackingStart(userID))
        return now
    }
}
