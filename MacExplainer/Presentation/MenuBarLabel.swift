import AppKit
import SwiftUI

struct MenuBarLabel: View {
    var session: AppSession

    var body: some View {
        Image(systemName: "waveform.path.ecg")
            .foregroundStyle(levelColor)
    }

    private var levelColor: Color {
        if let level = session.interpreted?.level {
            return level.tintColor
        }
        return .secondary
    }
}

struct MenuBarContent: View {
    @Environment(AppSession.self) private var session
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: levelImage)
                    .foregroundStyle(levelColor)
                Text(summary)
                    .font(.headline)
            }
            if let reasons = session.interpreted?.reasons, !reasons.isEmpty {
                ForEach(reasons) { reason in
                    Text(reason.headline)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if session.state != .active {
                Text("Measuring\u{2026}")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Divider().padding(.vertical, 4)
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open MacExplainer", systemImage: "arrow.up.forward.app")
            }
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .padding()
        .frame(width: 280)
    }

    private var summary: String {
        if let interpreted = session.interpreted {
            return interpreted.summary
        }
        return "Measuring\u{2026}"
    }

    private var levelColor: Color {
        if let level = session.interpreted?.level {
            return level.tintColor
        }
        return .secondary
    }

    private var levelImage: String {
        if let level = session.interpreted?.level {
            return level.systemImage
        }
        return "questionmark.circle"
    }
}
