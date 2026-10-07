import AppKit
import SwiftUI

struct OverviewView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                switch session.state {
                case .idle:
                    ContentUnavailableView("Not running", systemImage: "waveform.path.ecg", description: Text("The monitor has not started yet."))
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                case .measuring:
                    measuring
                        .transition(.opacity)
                case .active:
                    readout
                    whatIsHappening
                    topApps
                    recentHistory
                }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .animation(Motion.respecting(Motion.settle, reduceMotion: reduceMotion), value: session.state)
    }

    private var measuring: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "Taking a reading")
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Watching your Mac for a moment\u{2026}")
                    .font(Typeface.prose(15))
                    .foregroundStyle(Palette.inkSoft)
            }
            .paperCard()
        }
    }

    // MARK: - The readout

    private var readout: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Live reading")
                    .font(Typeface.eyebrow())
                    .tracking(1.1)
                    .foregroundStyle(Palette.readoutSoft)
                LiveDot(tint: healthColor)
                Spacer()
                if let snapshot = session.current {
                    Text("CPU \(Formatters.percent(snapshot.cpu.totalUsedPercent))")
                        .font(Typeface.data(12))
                        .monospacedDigit()
                        .foregroundStyle(Palette.readoutSoft)
                }
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    if let interpreted = session.interpreted {
                        Text(interpreted.summary)
                            .font(Typeface.verdict())
                            .foregroundStyle(Palette.readoutInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)
                            .animation(Motion.respecting(Motion.drift, reduceMotion: reduceMotion), value: session.interpreted?.summary)
                    }
                    Text(cpuMemoryLine)
                        .font(Typeface.label(12.5))
                        .foregroundStyle(Palette.readoutSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !recentFiveMinutes.isEmpty {
                    PulseTrace(points: recentFiveMinutes, keyPath: \.cpuUsedPercent, tint: Palette.accent)
                        .frame(width: 168, height: 58)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Palette.readoutCard)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Palette.readoutRule, lineWidth: 1)
                        )
                }
            }

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text("CPU")
                        .font(Typeface.label(11))
                        .foregroundStyle(Palette.readoutSoft)
                        .frame(width: 46, alignment: .leading)
                    GaugeBar(fraction: cpuFraction, tint: healthColor)
                    MetricValue(
                        text: Formatters.percent(cpuPercent),
                        font: Typeface.data(12),
                        color: Palette.readoutInk
                    )
                    .frame(width: 44, alignment: .trailing)
                }
                HStack(spacing: 8) {
                    Text("Memory")
                        .font(Typeface.label(11))
                        .foregroundStyle(Palette.readoutSoft)
                        .frame(width: 46, alignment: .leading)
                    GaugeBar(fraction: memoryFraction, tint: Palette.accent)
                    MetricValue(
                        text: Formatters.bytes(usedBytes),
                        font: Typeface.data(12),
                        color: Palette.readoutInk
                    )
                    .frame(width: 62, alignment: .trailing)
                }
            }

            Rectangle()
                .fill(Palette.readoutRule)
                .frame(height: 1)

            rateTiles
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Metrics.readoutRadius, style: .continuous)
                .fill(Palette.readout)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.readoutRadius, style: .continuous)
                .strokeBorder(Palette.readoutRule, lineWidth: 1)
        )
    }

    private var rateTiles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Right now")
                .font(Typeface.label(11))
                .foregroundStyle(Palette.readoutSoft)
            HStack(spacing: 10) {
                if let snapshot = session.current {
                    ReadoutTile(
                        label: MetricGlossary.diskRead,
                        title: "Disk read",
                        value: Formatters.rate(snapshot.disk.bytesPerSecondIn)
                    )
                    ReadoutTile(
                        label: MetricGlossary.diskWrite,
                        title: "Disk write",
                        value: Formatters.rate(snapshot.disk.bytesPerSecondOut)
                    )
                    ReadoutTile(
                        label: MetricGlossary.networkDown,
                        title: "Network down",
                        value: Formatters.rate(snapshot.network.bytesPerSecondIn)
                    )
                    ReadoutTile(
                        label: MetricGlossary.networkUp,
                        title: "Network up",
                        value: Formatters.rate(snapshot.network.bytesPerSecondOut)
                    )
                    if let battery = snapshot.battery {
                        ReadoutTile(
                            label: MetricGlossary.battery,
                            title: "Battery",
                            value: "\(battery.percent)%",
                            caption: battery.isCharging ? "Charging" : "On battery"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Paper

    private var whatIsHappening: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "What's happening")
            if let reasons = session.interpreted?.reasons, !reasons.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(reasons.enumerated()), id: \.element.id) { index, reason in
                        ReasonRow(reason: reason, showRule: index > 0)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity
                            ))
                    }
                }
                .paperCard()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nothing needs your attention.")
                        .font(Typeface.proseEmphasis(16))
                        .foregroundStyle(Palette.ink)
                    Text("Your Mac is comfortably handling everything that is open.")
                        .font(Typeface.prose(13.5))
                        .foregroundStyle(Palette.inkSoft)
                }
                .paperCard()
            }
        }
        .animation(Motion.respecting(Motion.drift, reduceMotion: reduceMotion), value: session.interpreted?.reasons)
    }

    private var topApps: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "What's using your Mac")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(topAppGroups) { group in
                    TopAppRow(group: group)
                        .transition(.opacity)
                }
            }
            .paperCard(padding: 14)
        }
        .animation(Motion.respecting(Motion.settle, reduceMotion: reduceMotion), value: topAppGroups)
    }

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "Last five minutes")
            HStack(spacing: 12) {
                PaperChartCard(
                    title: "Processor use",
                    entry: MetricGlossary.cpu,
                    note: "Spikes are normal; a flat high line is worth a look."
                ) {
                    CPUHistoryChart(points: recentFiveMinutes)
                        .frame(height: 96)
                }
                PaperChartCard(
                    title: "Memory pressure",
                    entry: MetricGlossary.memoryPressure,
                    note: "How hard macOS is working to find room in memory."
                ) {
                    PressureHistoryChart(points: recentFiveMinutes)
                        .frame(height: 96)
                }
            }
        }
    }

    // MARK: - Derived

    private var topAppGroups: [ProcessGroupStats] {
        session.appGroups.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(5).map { $0 }
    }

    private var recentFiveMinutes: [HistoryPoint] {
        let cutoff = Date().addingTimeInterval(-300)
        return session.historyPoints.filter { $0.timestamp >= cutoff }
    }

    private var cpuMemoryLine: String {
        guard let snapshot = session.current else { return "" }
        let cpu = Formatters.percent(snapshot.cpu.totalUsedPercent)
        let used = Formatters.bytes(snapshot.memory.usedBytes)
        return "CPU \(cpu)  \u{00B7}  About \(used) of RAM in use"
    }

    private var cpuPercent: Double { session.current?.cpu.totalUsedPercent ?? 0 }
    private var cpuFraction: Double { cpuPercent / 100 }
    private var usedBytes: UInt64 { session.current?.memory.usedBytes ?? 0 }
    private var memoryFraction: Double { session.current?.memory.usedFraction ?? 0 }
    private var healthColor: Color {
        Palette.health(session.interpreted?.level ?? .normal)
    }
}

// MARK: - Rows

private struct ReasonRow: View {
    let reason: HealthReason
    let showRule: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showRule {
                Rectangle()
                    .fill(Palette.rule)
                    .frame(height: 1)
                    .padding(.bottom, 12)
            }
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(Palette.ink.opacity(0.35))
                    .frame(width: 5, height: 5)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(reason.headline)
                        .font(Typeface.proseEmphasis(15))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(reason.detail)
                        .font(Typeface.prose(13))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct TopAppRow: View {
    let group: ProcessGroupStats

    var body: some View {
        HStack(spacing: 10) {
            ProcessIconView(pid: group.pid ?? -1)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.name)
                    .font(Typeface.label(13))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(group.processCount == 1 ? "1 process" : "\(group.processCount) processes")
                    .font(Typeface.label(10.5))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 12)
            MetricValue(text: Formatters.percent(group.cpuPercent), font: Typeface.data(12.5))
                .frame(width: 52, alignment: .trailing)
            MetricValue(text: Formatters.bytes(group.memoryBytes), font: Typeface.data(12.5), color: Palette.inkSoft)
                .frame(width: 68, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }
}

private struct PaperChartCard<Content: View>: View {
    let title: String
    let entry: GlossaryEntry
    let note: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GlossaryLabel(entry: entry, title: title, font: Typeface.heading(13), tint: Palette.ink, showsGlyph: true)
                Spacer()
            }
            content
            Text(note)
                .font(Typeface.prose(11.5))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .paperCard(padding: 14)
    }
}

struct LiveDot: View {
    var tint: Color = Palette.accent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBright = false

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 6, height: 6)
            .opacity(reduceMotion ? 1 : (isBright ? 1 : 0.45))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Motion.pulse.repeatForever(autoreverses: true)) {
                    isBright = true
                }
            }
    }
}

struct ProcessIconView: View {
    let pid: Int32

    var body: some View {
        Group {
            if let icon = NSRunningApplication(processIdentifier: pid)?.icon {
                Image(nsImage: icon)
                    .resizable()
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(width: 20, height: 20)
    }
}
