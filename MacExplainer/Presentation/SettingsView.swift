import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppPreferences.self) private var preferences
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Monitoring") {
                Picker("Sample every", selection: Binding(
                    get: { preferences.sampleInterval },
                    set: { newValue in
                        preferences.sampleInterval = newValue
                        session.setSampleInterval(newValue)
                    }
                )) {
                    ForEach(AppPreferences.supportedIntervals, id: \.self) { interval in
                        Text("\(Int(interval)) \(interval == 1 ? "second" : "seconds")").tag(interval)
                    }
                }
                Picker("History", selection: Binding(
                    get: { preferences.historyWindow },
                    set: { preferences.historyWindow = $0 }
                )) {
                    ForEach(HistoryWindow.allCases, id: \.self) { window in
                        Text(window.title).tag(window)
                    }
                }
            }

            Section("Menu bar") {
                Toggle("Show menu bar icon", isOn: Binding(
                    get: { preferences.showsMenuBarExtra },
                    set: { preferences.showsMenuBarExtra = $0 }
                ))
            }

            Section("Start at login") {
                Toggle("Open at login", isOn: Binding(
                    get: { preferences.startsAtLogin },
                    set: { toggleLogin($0) }
                ))
                Text(LoginItemService.statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .alert("Start at login", isPresented: Binding(
            get: { loginError != nil },
            set: { if !$0 { loginError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginError ?? "")
        }
    }

    private func toggleLogin(_ newValue: Bool) {
        do {
            try LoginItemService.setEnabled(newValue)
            preferences.startsAtLogin = newValue
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription)"
        }
    }
}
