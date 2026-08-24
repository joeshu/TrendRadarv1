import SwiftUI
import BackgroundTasks

@main
struct TrendRadarApp: App {
    @StateObject private var store = NewsStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var reportStore = ReportStore()
    @StateObject private var hotNewsStore = HotNewsStore()
    @StateObject private var bootstrapper = AppBootstrapper()

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
                .environmentObject(bootstrapper)
                .task {
                    await bootstrapper.start(
                        newsStore: store,
                        settingsStore: settingsStore,
                        reportStore: reportStore,
                        hotNewsStore: hotNewsStore
                    )
                }
        }
    }
}
