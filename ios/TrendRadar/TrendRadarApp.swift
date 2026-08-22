import SwiftUI
import BackgroundTasks

@main
struct TrendRadarApp: App {
    @StateObject private var store = NewsStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var reportStore = ReportStore()
    @StateObject private var hotNewsStore = HotNewsStore()

    init() {
        BackgroundRefreshService.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settingsStore)
                .environmentObject(reportStore)
                .environmentObject(hotNewsStore)
                .task {
                    await store.load()
                    store.settings = settingsStore.settings
                    await loadSecondaryStores()
                    await compensateMissedForegroundRunIfNeeded()
                    BackgroundRefreshService.schedule(
                        after: settingsStore.settings.refreshInterval * 60,
                        enabled: settingsStore.settings.scheduleEnabled
                    )
                }
        }
    }

    @MainActor
    private func compensateMissedForegroundRunIfNeeded() async {
        guard settingsStore.settings.scheduleEnabled else { return }
        let interval = settingsStore.settings.refreshInterval * 60
        guard RefreshExecutionLog.shouldCompensate(interval: interval) else { return }
        await store.refresh(showError: false, autoReport: false)
        await hotNewsStore.refresh(settings: settingsStore.settings, showError: false)
        guard !store.items.isEmpty || !hotNewsStore.items.isEmpty else { return }
        let type = ReportType(rawValue: settingsStore.settings.report.mode) ?? .current
        await reportStore.generate(
            type: type,
            settings: settingsStore.settings,
            items: store.items,
            hotlistItems: hotNewsStore.items,
            trigger: .foregroundRefresh,
            batchID: "foreground-compensation:\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        )
        RefreshExecutionLog.record(RefreshExecutionRecord(trigger: .foreground, status: .completed))
    }

    @MainActor
    private func loadSecondaryStores() async {
        await reportStore.load()
        await hotNewsStore.load()
        await reportStore.applyRetentionPolicy(days: settingsStore.settings.storage.localRetentionDays)
    }
}
