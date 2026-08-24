import Foundation

@MainActor
final class SafeStartupManager {
    static let shared = SafeStartupManager()

    private let defaultsKey = "trendradar.safeStartupState"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func beginLaunch() -> SafeStartupState {
        var state = load()
        state.lastLaunchAt = Date()
        save(state)
        return state
    }

    func markHealthy() {
        var state = load()
        state.status = .normal
        state.lastFailureMessage = nil
        state.failureCount = 0
        save(state)
    }

    func markFailure(_ error: Error) {
        var state = load()
        state.status = .recoveryRequired
        state.lastFailureMessage = error.localizedDescription
        state.failureCount += 1
        save(state)
    }

    func markDegraded(_ message: String) {
        var state = load()
        state.status = .degraded
        state.lastFailureMessage = message
        save(state)
    }

    func clearRecovery() {
        save(.initial)
    }

    func currentState() -> SafeStartupState {
        load()
    }

    func shouldRecover() -> Bool {
        load().status == .recoveryRequired
    }

    private func load() -> SafeStartupState {
        guard let data = defaults.data(forKey: defaultsKey),
              let state = try? JSONDecoder().decode(SafeStartupState.self, from: data) else {
            return .initial
        }
        return state
    }

    private func save(_ state: SafeStartupState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
