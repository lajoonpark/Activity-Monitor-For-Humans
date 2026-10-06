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
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
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
            return Palette.health(level)
        }
        return .secondary
    }
}

struct MenuBarContent: View {
    @Environment(AppSession.self) private var session
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            readoutStrip
            VStack(alignment: .leading, spacing: 10) {
                if let reasons = session.interpreted?.reasons, !reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(reasons) { reason in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reason.headline)
                                    .font(Typeface.proseEmphasis(13))
                                    .foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(reason.detail)
                                    .font(Typeface.prose(11.5))
                                    .foregroundStyle(Palette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } else if session.state != .active {
                    Text("Taking a reading\u{2026}")
                        .font(Typeface.prose(13))
                        .foregroundStyle(Palette.inkSoft)
                } else {
                    Text("Nothing needs your attention.")
                        .font(Typeface.prose(13))
                        .foregroundStyle(Palette.inkSoft)
                }

                if let snapshot = session.current {
                    HStack(spacing: 6) {
                        Text("CPU")
                            .font(Typeface.label(10.5))
                            .foregroundStyle(Palette.inkSoft)
                        MetricValue(text: Formatters.percent(snapshot.cpu.totalUsedPercent), font: Typeface.data(11.5))
                        Text("\u{00B7}")
                            .foregroundStyle(Palette.inkSoft)
                        Text("RAM")
                            .font(Typeface.label(10.5))
                            .foregroundStyle(Palette.inkSoft)
                        MetricValue(text: Formatters.bytes(snapshot.memory.usedBytes), font: Typeface.data(11.5), color: Palette.inkSoft)
                        Spacer()
                    }
                }

                Rectangle()
                    .fill(Palette.rule)
                    .frame(height: 1)

                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open TIM", systemImage: "arrow.up.forward.app")
                        .font(Typeface.label(12))
                }
                .buttonStyle(.plain)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .font(Typeface.label(12))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
        .frame(width: 300)
        .background(Palette.paper)
    }

    private var readoutStrip: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Palette.health(session.interpreted?.level ?? .normal))
                    .frame(width: 7, height: 7)
                Text("Your Mac, right now")
                    .font(Typeface.eyebrow())
                    .tracking(1)
                    .foregroundStyle(Palette.readoutSoft)
            }
            Text(summary)
                .font(Typeface.proseEmphasis(16))
                .foregroundStyle(Palette.readoutInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.readout)
    }

    private var summary: String {
        if let interpreted = session.interpreted {
            return interpreted.summary
        }
        return "Taking a reading\u{2026}"
    }
}
