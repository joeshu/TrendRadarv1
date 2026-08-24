import BackgroundTasks
import Foundation

enum BackgroundRefreshService {
    static let identifier = "com.trendradar.mobile.refresh"

    static var isSupportedHost: Bool {
        isSupportedHost(processName: ProcessInfo.processInfo.processName, bundlePath: Bundle.main.bundleURL.path)
    }

    static func isSupportedHost(processName: String, bundlePath: String) -> Bool {
        let processName = processName.lowercased()
        let bundlePath = bundlePath.lowercased()
        let isLiveContainer = processName.hasPrefix("liveprocess") || bundlePath.contains("/documents/applications/")
        return !isLiveContainer && bundlePath.hasSuffix(".app")
    }

    @discardableResult
    static func register() -> Bool {
        guard isSupportedHost else { return false }
        return BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            Task { await run(task: task) }
        }
    }

    static func schedule(after interval: TimeInterval = 3600, enabled: Bool = true) {
        guard isSupportedHost else { return }
        guard enabled else { BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier); return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run(task: BGAppRefreshTask) async {
        let work = Task { await refresh(task: task) }
        task.expirationHandler = { work.cancel() }
        await work.value
    }

    private static func refresh(task: BGAppRefreshTask) async {
        let settings = loadSettings()
        let startedAt = Date()
        do {
            let result = try await BackgroundRefreshPipelineAdapter.execute()
            RefreshExecutionLog.record(RefreshExecutionRecord(trigger: .background, startedAt: startedAt, finishedAt: Date(), status: result.sourceErrors.isEmpty ? .completed : .partial, errorMessages: result.sourceErrors))
            schedule(after: settings.refreshInterval * 60, enabled: settings.scheduleEnabled)
            task.setTaskCompleted(success: true)
        } catch {
            RefreshExecutionLog.record(RefreshExecutionRecord(trigger: .background, startedAt: startedAt, finishedAt: Date(), status: error is CancellationError ? .cancelled : .failed, errorMessages: ["background": error.localizedDescription]))
            schedule(after: 3600, enabled: settings.scheduleEnabled)
            task.setTaskCompleted(success: false)
        }
    }

    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "trendradar.settings"), let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return settings
    }
}

