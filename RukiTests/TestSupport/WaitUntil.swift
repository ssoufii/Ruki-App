import Foundation

/// Polls `condition` until it holds or `timeout` passes, returning whether it held.
///
/// Use this instead of a fixed `Task.sleep` when a test waits on a fire-and-forget
/// `Task`. A fixed sleep is a race: it passes on a fast machine and fails under
/// load (which is how five SettingsViewModel tests went red locally while CI was
/// green). Polling passes as soon as the work is done and only fails on a real miss.
func waitUntil(
    timeout: Duration = .seconds(5),
    pollEvery interval: Duration = .milliseconds(5),
    _ condition: () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: interval)
    }
    return await condition()
}
