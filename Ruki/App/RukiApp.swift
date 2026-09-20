import SwiftUI

@main
struct RukiApp: App {
    @State private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .task { await refresh() }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await refresh() }
                }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) {
            await refresh()
        }
    }

    /// What app launch, returning to the foreground, and a background-refresh
    /// wake-up all call: re-plan the 12-day notification horizon (RUKI-015)
    /// against whatever's currently enabled. Settings and pause changes get
    /// their own hooks from the screens that own those triggers (RUKI-036,
    /// RUKI-034) — this is only launch/foreground/background-wake.
    @MainActor
    private func refresh() async {
        let inputs = environment.userSettings.promptInputs
        try? await environment.backgroundRefresh.refreshAndScheduleNext(inputs: inputs)
    }
}
