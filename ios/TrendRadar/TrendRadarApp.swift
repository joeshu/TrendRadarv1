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
                    BackgroundRefreshService.schedule(
                        after: settingsStore.settings.refreshInterval * 60,
                        enabled: settingsStore.settings.scheduleEnabled
                    )
                }
        }
    }

    @MainActor
    private func loadSecondaryStores() async {
        await reportStore.load()
        await hotNewsStore.load()
        await reportStore.applyRetentionPolicy(days: settingsStore.settings.storage.localRetentionDays)
    }
}
