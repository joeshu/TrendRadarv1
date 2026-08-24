import Foundation

/// Startup recovery state used to avoid launch failures taking down the app.
struct SafeStartupState: Codable, Sendable {
    enum Status: String, Codable, Sendable {
        case normal
        case degraded
        case recoveryRequired
    }

    var status: Status
    var lastLaunchAt: Date
    var lastFailureMessage: String?
    var failureCount: Int

    static var initial: SafeStartupState {
        SafeStartupState(
            status: .normal,
            lastLaunchAt: Date(),
            lastFailureMessage: nil,
            failureCount: 0
        )
    }
}
