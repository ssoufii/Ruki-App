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
    /// wake-up all call. `AppEnvironment.refreshBackgroundSchedule` is the
    /// shared implementation — `TodayView`'s pause flow (RUKI-034) calls it
    /// too, right after recording a pause.
    @MainActor
    private func refresh() async {
        await environment.refreshBackgroundSchedule()
    }
}
