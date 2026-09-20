import Foundation
@testable import Ruki

/// In-memory `NotificationScheduling` fake. Tracks the last replaced set so
/// tests can assert on the 64-notification ceiling and what `PromptScheduler`
/// actually requested, without touching `UNUserNotificationCenter`.
actor FakeNotificationScheduler: NotificationScheduling {
    private(set) var scheduled: [PromptSpec] = []
    private(set) var lastSoundEnabled: Bool?
    private(set) var replaceCallCount = 0

    func replacePending(with specs: [PromptSpec], soundEnabled: Bool) async throws {
        guard specs.count <= PromptPlanner.maxPending else {
            throw NotificationSchedulingError.tooManyPending(specs.count)
        }
        scheduled = specs
        lastSoundEnabled = soundEnabled
        replaceCallCount += 1
    }

    func pendingCount() async -> Int {
        scheduled.count
    }
}
