import AppKit
import SwiftUI

struct OverviewView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch session.state {
                case .idle:
                    ContentUnavailableView("Not running", systemImage: "waveform.path.ecg", description: Text("The monitor has not started yet."))
                case .measuring:
                    ProgressView("Measuring\u{2026}")
                case .active:
                    healthHeader
                    topApps
                    ratesRow
                    miniCharts
                }
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var healthHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: levelImage)
                    .font(.system(size: 34))
                    .foregroundStyle(levelColor)
                VStack(alignment: .leading, spacing: 2) {
                    if let interpreted = session.interpreted {
                        Text(interpreted.summary)
                            .font(.title2)
                            .bold()
                        Text(cpuMemoryLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let reasons = session.interpreted?.reasons {
                ForEach(reasons) { reason in
                    Text("• " + reason.headline)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(levelColor.opacity(0.12)))
    }

    private var cpuMemoryLine: String {
        guard let snapshot = session.current else { return "" }
        let cpu = Formatters.percent(snapshot.cpu.totalUsedPercent)
        let used = Formatters.bytes(snapshot.memory.usedBytes)
        return "CPU \(cpu)  \u{00B7}  About \(used) of RAM in use"
    }

    private var topApps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top apps")
                .font(.headline)
            ForEach(session.appGroups.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(5)) { group in
                HStack(spacing: 8) {
                    ProcessIconView(pid: group.pid ?? -1)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.name)
                            .lineLimit(1)
                        Text("\(group.processCount) processes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Formatters.percent(group.cpuPercent))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(Formatters.bytes(group.residentBytes))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var ratesRow: some View {
        HStack(spacing: 12) {
            if let snapshot = session.current {
                RateTile(title: "Disk read", value: Formatters.rate(snapshot.disk.bytesPerSecondIn))
                RateTile(title: "Disk write", value: Formatters.rate(snapshot.disk.bytesPerSecondOut))
                RateTile(title: "Network down", value: Formatters.rate(snapshot.network.bytesPerSecondIn))
                RateTile(title: "Network up", value: Formatters.rate(snapshot.network.bytesPerSecondOut))
                if let battery = snapshot.battery {
                    RateTile(title: "Battery", value: "\(battery.percent)%")
                }
            }
        }
    }

    private var miniCharts: some View {
        HStack(spacing: 12) {
            ChartCard("CPU (5 min)") {
                CPUHistoryChart(points: recentFiveMinutes)
                    .frame(height: 110)
            }
            ChartCard("Memory pressure (5 min)") {
                PressureHistoryChart(points: recentFiveMinutes)
                    .frame(height: 110)
            }
        }
    }

    private var recentFiveMinutes: [HistoryPoint] {
        let cutoff = Date().addingTimeInterval(-300)
        return session.historyPoints.filter { $0.timestamp >= cutoff }
    }

    private var levelColor: Color {
        session.interpreted?.level.tintColor ?? .gray
    }

    private var levelImage: String {
        session.interpreted?.level.systemImage ?? "questionmark.circle"
    }
}

private struct RateTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
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
            }
        }
        .frame(width: 18, height: 18)
        .padding(2)
        .help("")
    }
}
