import AppKit
import SwiftUI

struct MenuBarLabel: View {
    var session: AppSession
    var preferences: AppPreferences

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(levelColor)
            if preferences.menuBarMetrics == .inMenuBar, !metricsLine.isEmpty {
                Text(metricsLine)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metricsLine: String {
        guard let snapshot = session.current else { return "" }
        let used = snapshot.memory.usedBytes
        return "\(Formatters.percent(snapshot.cpu.totalUsedPercent)) \(Formatters.bytes(used))"
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
            if let snapshot = session.current {
                Text("CPU \(Formatters.percent(snapshot.cpu.totalUsedPercent))  \u{00B7}  RAM about \(Formatters.bytes(snapshot.memory.usedBytes))")
                    .font(.callout)
                    .monospacedDigit()
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
