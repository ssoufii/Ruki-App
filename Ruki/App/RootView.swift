import SwiftUI

/// The one view `RukiApp` shows. Routes between onboarding (RUKI-011) and
/// the app's main flow (T2's Today screen), and — independent of that
/// destination — covers everything with a specific prayer's check-in
/// whenever `AppRouter.pendingCheckInSlotID` is set (RUKI-014: a tapped
/// prompt opens directly to check-in, with no Today-screen stop first).
struct RootView: View {
    let environment: AppEnvironment

    var body: some View {
        Group {
            switch environment.router.destination {
            case .onboarding:
                OnboardingFlow(
                    userSettings: environment.userSettings,
                    clock: environment.clock,
                    notificationAuthorizer: environment.notificationAuthorizer
                )
            case .today:
                TodayView(
                    timeline: environment.timeline,
                    clock: environment.clock,
                    userSettings: environment.userSettings,
                    historyStore: environment.historyStore,
                    cameraProvider: environment.cameraProvider,
                    social: environment.social,
                    notificationAuthorizer: environment.notificationAuthorizer,
                    onScheduleAffectingChange: { await environment.refreshBackgroundSchedule() },
                    onDeleteAllData: { await environment.deleteAllOnDeviceData() },
                    onDebugSendTestPrompt: { await environment.scheduleDebugTestPrompt() },
                    refreshTrigger: environment.router.checkInDismissals
                )
            }
        }
        .background(RukiPalette.background)
        .fullScreenCover(isPresented: pendingCheckInPresented) {
            // Straight from the tap into the check-in — no Today-screen stop
            // (RUKI-014) — but resolved against *now*: a prompt tapped after
            // the window closed, or after checking in, must not open a camera.
            PendingCheckInView(route: pendingCheckInRoute)
        }
    }

    private var pendingCheckInPresented: Binding<Bool> {
        Binding(
            get: { environment.router.pendingCheckInSlotID != nil },
            set: { isPresented in
                if !isPresented { environment.router.dismissCheckIn() }
            }
        )
    }

    private var pendingCheckInRoute: CheckInRouteResolver.Route {
        guard let slotID = environment.router.pendingCheckInSlotID else { return .unknown }
        return CheckInRouteResolver(
            timeline: environment.timeline,
            clock: environment.clock,
            userSettings: environment.userSettings,
            historyStore: environment.historyStore,
            cameraProvider: environment.cameraProvider,
            publisher: environment.social
        ).route(forSlotID: slotID)
    }
}

#Preview {
    RootView(environment: AppEnvironment())
}
