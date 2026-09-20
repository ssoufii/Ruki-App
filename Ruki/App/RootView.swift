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
                    notificationAuthorizer: environment.notificationAuthorizer,
                    onScheduleAffectingChange: { await environment.refreshBackgroundSchedule() },
                    onDeleteAllData: { await environment.deleteAllOnDeviceData() },
                    onDebugSendTestPrompt: { await environment.scheduleDebugTestPrompt() }
                )
            }
        }
        .background(RukiPalette.background)
        .fullScreenCover(isPresented: pendingCheckInPresented) {
            // A real `CheckInFlowView` needs a `CameraProviding`, which
            // doesn't exist yet outside test fakes (RUKI-020 builds the
            // real and Simulator-placeholder providers). Until then this
            // matches `TodayView`'s own check-in doorway — the routing
            // itself (straight from the tap, no interstitial) is what this
            // story delivers.
            ComingSoonScreen(title: pendingCheckInTitle)
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

    private var pendingCheckInTitle: String {
        guard
            let slotID = environment.router.pendingCheckInSlotID,
            let prayer = PrayerSlot.prayer(fromID: slotID)
        else {
            return String(localized: "Check-in")
        }
        return String(localized: "Check in for \(prayer.displayName)")
    }
}

#Preview {
    RootView(environment: AppEnvironment())
}
