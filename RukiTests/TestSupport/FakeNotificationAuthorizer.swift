import Foundation
@testable import Ruki

/// In-memory `NotificationAuthorizing` fake.
actor FakeNotificationAuthorizer: NotificationAuthorizing {
    private(set) var requestCount = 0
    var statusToReturn: NotificationAuthorizationStatus
    var grantOnRequest: Bool

    init(statusToReturn: NotificationAuthorizationStatus = .notDetermined, grantOnRequest: Bool = true) {
        self.statusToReturn = statusToReturn
        self.grantOnRequest = grantOnRequest
    }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        if grantOnRequest { statusToReturn = .authorized }
        return grantOnRequest
    }

    func currentStatus() async -> NotificationAuthorizationStatus {
        statusToReturn
    }
}
