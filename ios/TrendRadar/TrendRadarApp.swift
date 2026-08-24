import SwiftUI
import BackgroundTasks

@main
struct TrendRadarApp: App {
    @StateObject private var store = NewsStore()
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var reportStore = ReportStore()
    @StateObject private var hotNewsStore = HotNewsStore()
    @StateObject private var bootstrapper = AppBootstrapper()
    @StateObject private var archiveStore = ArchiveStore()

    init() {
        BackgroundRefreshService.register()
    }

    var body: some Scene {
        WindowGroup {
            appContent
        }
    }

    private var appContent: some View {
        AppTheme.fontScale = settingsStore.settings.display.fontScale
        return ContentView()
                .font(AppTheme.bodyFont)
                .environmentObject(store)
                .environmentObject(settingsStore)
                .environmentObject(reportStore)
                .environmentObject(hotNewsStore)
                .environmentObject(bootstrapper)
                .environmentObject(archiveStore)
                .preferredColorScheme(preferredColorScheme)
                .dynamicTypeSize(.medium)
                .controlSize(controlSize)
                .environment(\.appHighContrast, settingsStore.settings.display.highContrast)
                .environment(\.appReduceTransparency, settingsStore.settings.display.reduceTransparency)
                .environment(\.defaultMinListRowHeight, 48 * settingsStore.settings.display.uiScale)
                .task {
                    await bootstrapper.start(
                        newsStore: store,
                        settingsStore: settingsStore,
                        reportStore: reportStore,
                        hotNewsStore: hotNewsStore
                    )
                }
    }

    private var preferredColorScheme: ColorScheme? {
        switch settingsStore.settings.display.appearance {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    private var controlSize: ControlSize {
        switch settingsStore.settings.display.uiScale {
        case ..<0.98: return .small
        case 1.08...: return .large
        default: return .regular
        }
    }
}
