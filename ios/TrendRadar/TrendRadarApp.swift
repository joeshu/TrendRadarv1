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
            ContentView()
                .environmentObject(store)
                .environmentObject(settingsStore)
                .environmentObject(reportStore)
                .environmentObject(hotNewsStore)
                .environmentObject(bootstrapper)
                .environmentObject(archiveStore)
                .preferredColorScheme(preferredColorScheme)
                .dynamicTypeSize(dynamicTypeSize)
                .fontDesign(fontDesign)
                .controlSize(controlSize)
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
    }

    private var preferredColorScheme: ColorScheme? {
        switch settingsStore.settings.display.appearance {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    private var fontDesign: Font.Design {
        switch settingsStore.settings.display.fontStyle {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        }
    }

    private var dynamicTypeSize: DynamicTypeSize {
        switch settingsStore.settings.display.fontScale {
        case ..<0.90: return .small
        case ..<0.98: return .medium
        case ..<1.05: return .large
        case ..<1.10: return .xLarge
        case ..<1.15: return .xxLarge
        case ..<1.20: return .xxxLarge
        case ..<1.25: return .accessibility1
        case ..<1.30: return .accessibility2
        default: return .accessibility3
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
