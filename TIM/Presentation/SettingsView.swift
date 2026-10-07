import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppPreferences.self) private var preferences
    @State private var loginError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionEyebrow(title: "Monitoring")
                VStack(alignment: .leading, spacing: 0) {
                    SettingsRow(
                        title: "Take a reading every",
                        caption: "More often gives fresher numbers and costs a little more background work."
                    ) {
                        Picker("", selection: Binding(
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
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    SettingsRow(
                        title: "Keep history for",
                        caption: "How far back the charts can see. Older readings are discarded."
                    ) {
                        Picker("", selection: Binding(
                            get: { preferences.historyWindow },
                            set: { preferences.historyWindow = $0 }
                        )) {
                            ForEach(HistoryWindow.allCases, id: \.self) { window in
                                Text(window.title).tag(window)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                }
                .paperCard(padding: 6)

                SectionEyebrow(title: "Menu bar")
                VStack(alignment: .leading, spacing: 0) {
                    SettingsRow(
                        title: "Show menu bar icon",
                        caption: "Keeps a quick reading of your Mac in the top-right corner."
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferences.showsMenuBarExtra },
                            set: { preferences.showsMenuBarExtra = $0 }
                        ))
                        .labelsHidden()
                    }
                    SettingsRow(
                        title: "Numbers in the menu bar",
                        caption: "Choose how much detail sits next to the icon."
                    ) {
                        Picker("", selection: Binding(
                            get: { preferences.menuBarMetrics },
                            set: { preferences.menuBarMetrics = $0 }
                        )) {
                            Text("Icon only").tag(MenuBarMetricsStyle.popupOnly)
                            Text("With numbers").tag(MenuBarMetricsStyle.inMenuBar)
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                }
                .paperCard(padding: 6)

                SectionEyebrow(title: "At startup")
                VStack(alignment: .leading, spacing: 0) {
                    SettingsRow(
                        title: "Open at login",
                        caption: "Starts watching your Mac as soon as you sign in."
                    ) {
                        Toggle("", isOn: Binding(
                            get: { preferences.startsAtLogin },
                            set: { toggleLogin($0) }
                        ))
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LoginItemService.statusDescription)
                            .font(Typeface.prose(11.5))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .paperCard(padding: 6)
            }
            .padding(20)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
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

private struct SettingsRow<Control: View>: View {
    let title: String
    let caption: String
    @ViewBuilder var control: Control

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Palette.rule)
                .frame(height: 1)
                .padding(.leading, 12)
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Typeface.label(13))
                        .foregroundStyle(Palette.ink)
                    Text(caption)
                        .font(Typeface.prose(11.5))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                control
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
    }
}
