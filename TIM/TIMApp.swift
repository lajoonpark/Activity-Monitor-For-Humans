import AppKit
import SwiftUI

var isRunningUnitTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

struct ContentView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        if isRunningUnitTests {
            Color.clear.frame(width: 1, height: 1)
        } else {
            @Bindable var router = router
            TabView(selection: $router.selectedTab) {
                OverviewView()
                    .tabItem { Label("Overview", systemImage: "waveform.path.ecg") }
                    .tag(AppTab.overview)
                AppsView()
                    .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
                    .tag(AppTab.apps)
                EnergyView()
                    .tabItem { Label("Energy", systemImage: "bolt") }
                    .tag(AppTab.energy)
                HistoryView()
                    .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(AppTab.history)
                WikiView()
                    .tabItem { Label("Wiki", systemImage: "book.closed") }
                    .tag(AppTab.wiki)
                AdvancedView()
                    .tabItem { Label("Advanced", systemImage: "list.bullet.rectangle") }
                    .tag(AppTab.advanced)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(AppTab.settings)
            }
            .tint(Palette.accent)
            .frame(minWidth: 720, minHeight: 480)
            .onAppear {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

@main
struct TIMApp: App {
    @State private var preferences = AppPreferences()
    @State private var session: AppSession
    @State private var router = AppRouter()

    init() {
        let preferences = AppPreferences()
        let session = AppSession(preferences: preferences)
        _preferences = State(initialValue: preferences)
        _session = State(initialValue: session)
        if !isRunningUnitTests {
            session.start()
        }
    }

    var body: some Scene {
        WindowGroup("TIM", id: "main") {
            ContentView()
                .environment(session)
                .environment(preferences)
                .environment(router)
        }
        .defaultSize(width: 920, height: 640)

        MenuBarExtra(isInserted: menuBarInserted) {
            MenuBarContent()
                .environment(session)
                .environment(preferences)
                .environment(router)
        } label: {
            MenuBarLabel(session: session, preferences: preferences)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarInserted: Binding<Bool> {
        Binding(
            get: { isRunningUnitTests ? false : preferences.showsMenuBarExtra },
            set: { newValue in
                if !isRunningUnitTests { preferences.showsMenuBarExtra = newValue }
            }
        )
    }
}
