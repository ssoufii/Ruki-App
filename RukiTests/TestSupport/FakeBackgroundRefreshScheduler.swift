import Foundation
@testable import Ruki

/// In-memory `BackgroundRefreshScheduling` fake. Tracks every submitted
/// request so tests can assert on identifier and `earliestBeginDate` without
/// touching `BGTaskScheduler`.
actor FakeBackgroundRefreshScheduler: BackgroundRefreshScheduling {
    struct SubmittedRequest: Equatable {
        let identifier: String
        let earliestBeginDate: Date
    }

    enum SubmissionError: Error, Sendable {
        case forced
    }

    private(set) var submitted: [SubmittedRequest] = []
    private var shouldThrow = false

    func setShouldThrow() {
        shouldThrow = true
    }

    func submit(identifier: String, earliestBeginDate: Date) async throws {
        if shouldThrow {
            throw SubmissionError.forced
        }
        submitted.append(SubmittedRequest(identifier: identifier, earliestBeginDate: earliestBeginDate))
    }
}
