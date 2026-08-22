import SwiftUI

@main
struct TrendRadarApp: App {
    @StateObject private var store = NewsStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var reportStore = ReportStore()
    @StateObject private var hotNewsStore = HotNewsStore()

    init() {
        // BackgroundTasks registration is optional and can terminate unsupported hosts.
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
