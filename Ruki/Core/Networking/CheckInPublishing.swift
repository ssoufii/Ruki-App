import Foundation

/// The one thing a finished check-in needs from the social layer. Fire and
/// forget by contract: the check-in is already saved on-device, so a network
/// failure must never fail, delay or scold it (local-first; RDP-1 tone).
@MainActor
protocol CheckInPublishing: AnyObject {
    func publish(_ upload: CheckInUpload)
}
