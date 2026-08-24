import Foundation
import Combine

@MainActor
final class AppBootstrapper: ObservableObject {
    enum Phase: String, Codable, Sendable {
        case idle
        case loadingPrimaryStore
        case loadingSecondaryStores
        case compensatingRefresh
        case schedulingBackgroundRefresh
        case ready
        case degraded
    }

    struct Snapshot: Codable, Sendable {
        let phase: Phase
        let updatedAt: Date
        let message: String?
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var diagnosticMessage: String?

    private static let diagnosticKey = "trendradar.bootstrap.snapshot"

    func start(
        newsStore: NewsStore,
        settingsStore: SettingsStore,
        reportStore: ReportStore,
        hotNewsStore: HotNewsStore
    ) async {
        transition(to: .loadingPrimaryStore)
        await newsStore.load()
        newsStore.settings = settingsStore.settings

        transition(to: .loadingSecondaryStores)
        await reportStore.load()
        await hotNewsStore.load()
        await reportStore.applyRetentionPolicy(days: settingsStore.settings.storage.localRetentionDays)

        if settingsStore.settings.scheduleEnabled {
            transition(to: .compensatingRefresh)
            await compensateMissedRunIfNeeded(
                newsStore: newsStore,
                settingsStore: settingsStore,
                reportStore: reportStore,
                hotNewsStore: hotNewsStore
            )
        }

        transition(to: .schedulingBackgroundRefresh)
        BackgroundRefreshService.schedule(
            after: settingsStore.settings.refreshInterval * 60,
            enabled: settingsStore.settings.scheduleEnabled
        )
        transition(to: .ready)
    }

    static func lastSnapshot() -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: diagnosticKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private func compensateMissedRunIfNeeded(
        newsStore: NewsStore,
        settingsStore: SettingsStore,
        reportStore: ReportStore,
        hotNewsStore: HotNewsStore
    ) async {
        let interval = settingsStore.settings.refreshInterval * 60
        guard RefreshExecutionLog.shouldCompensate(interval: interval) else { return }

        await newsStore.refresh(showError: false, autoReport: false)
        await hotNewsStore.refresh(settings: settingsStore.settings, showError: false)
        guard !newsStore.items.isEmpty || !hotNewsStore.items.isEmpty else {
            transition(to: .degraded, message: "补偿刷新未取得数据，已保留本地内容")
            return
        }

        let type = ReportType(rawValue: settingsStore.settings.report.mode) ?? .current
        await reportStore.generate(
            type: type,
            settings: settingsStore.settings,
            items: newsStore.items,
            hotlistItems: hotNewsStore.items,
            trigger: .foregroundRefresh,
            batchID: "foreground-compensation:\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        )
        RefreshExecutionLog.record(RefreshExecutionRecord(trigger: .foreground, status: .completed))
    }

    private func transition(to phase: Phase, message: String? = nil) {
        self.phase = phase
        diagnosticMessage = message
        let snapshot = Snapshot(phase: phase, updatedAt: Date(), message: message)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.diagnosticKey)
        }
    }
}
