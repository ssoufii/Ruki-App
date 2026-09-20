import Foundation

/// RUKI-010: requests notification permission and always lets onboarding
/// continue afterward — granted, denied, or the request itself failing.
/// The app must stay fully usable without notification permission (M1's
/// solo-loop requirement); this is the one place that decision is encoded,
/// separately from the view so it's testable without rendering SwiftUI.
@MainActor
final class NotificationPermissionViewModel {
    private let authorizer: any NotificationAuthorizing

    init(authorizer: any NotificationAuthorizing) {
        self.authorizer = authorizer
    }

    func requestPermission() async {
        _ = try? await authorizer.requestAuthorization()
    }
}
