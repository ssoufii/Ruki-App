import Testing
@testable import Ruki

@MainActor
@Suite("NotificationPermissionViewModel")
struct NotificationPermissionViewModelTests {
    @Test("Requesting permission calls through to the authorizer exactly once")
    func requestsAuthorizationOnce() async {
        let authorizer = FakeNotificationAuthorizer(statusToReturn: .notDetermined, grantOnRequest: true)
        let viewModel = NotificationPermissionViewModel(authorizer: authorizer)

        await viewModel.requestPermission()

        #expect(await authorizer.requestCount == 1)
    }

    @Test("Completes without throwing even when the user denies (RUKI-010: onboarding must always be able to continue)")
    func completesWithoutThrowingWhenDenied() async {
        let authorizer = FakeNotificationAuthorizer(statusToReturn: .denied, grantOnRequest: false)
        let viewModel = NotificationPermissionViewModel(authorizer: authorizer)

        await viewModel.requestPermission()

        #expect(await authorizer.requestCount == 1)
        #expect(await authorizer.currentStatus() == .denied)
    }
}
