import AppKit
import SwiftUI

var isRunningUnitTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

struct ContentView: View {
    var body: some View {
        if isRunningUnitTests {
            Color.clear.frame(width: 1, height: 1)
        } else {
            TabView {
                OverviewView()
                    .tabItem { Label("Overview", systemImage: "waveform.path.ecg") }
                AppsView()
                    .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "chart.line.uptrend.xyaxis") }
                AdvancedView()
                    .tabItem { Label("Advanced", systemImage: "list.bullet.rectangle") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .frame(minWidth: 720, minHeight: 480)
            .onAppear {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

@main
struct MacExplainerApp: App {
    @State private var preferences = AppPreferences()
    @State private var session: AppSession

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
        WindowGroup("MacExplainer", id: "main") {
            ContentView()
                .environment(session)
                .environment(preferences)
        }
        .defaultSize(width: 920, height: 640)

        MenuBarExtra(isInserted: menuBarInserted) {
            MenuBarContent()
                .environment(session)
                .environment(preferences)
        } label: {
            MenuBarLabel(session: session)
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
