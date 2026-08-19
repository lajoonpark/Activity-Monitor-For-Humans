import SwiftUI

struct AdvancedView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let snapshot = session.current {
                    metricGrid(snapshot)
                    processTable
                } else {
                    ProgressView("Measuring\u{2026}")
                }
            }
            .padding()
        }
        .navigationTitle("Advanced")
    }

    private func metricGrid(_ snapshot: SystemSnapshot) -> some View {
        let rows: [(String, String)] = [
            ("CPU used", Formatters.percent(snapshot.cpu.totalUsedPercent)),
            ("CPU user / system", "\(Formatters.percent(snapshot.cpu.userPercent)) / \(Formatters.percent(snapshot.cpu.systemPercent))"),
            ("CPU idle", Formatters.percent(snapshot.cpu.idlePercent)),
            ("Physical memory", Formatters.bytes(snapshot.memory.physicalBytes)),
            ("Free", Formatters.bytes(snapshot.memory.freeBytes)),
            ("Active", Formatters.bytes(snapshot.memory.activeBytes)),
            ("Inactive", Formatters.bytes(snapshot.memory.inactiveBytes)),
            ("Wired", Formatters.bytes(snapshot.memory.wiredBytes)),
            ("Compressed", Formatters.bytes(snapshot.memory.compressedBytes)),
            ("Internal", Formatters.bytes(snapshot.memory.internalBytes)),
            ("External", Formatters.bytes(snapshot.memory.externalBytes)),
            ("Purgeable", Formatters.bytes(snapshot.memory.purgeableBytes)),
            ("Memory pressure", Self.pressureLabel(snapshot.memory.pressure)),
            ("Swap used", Formatters.bytes(snapshot.memory.swapUsedBytes)),
            ("Swap total", Formatters.bytes(snapshot.memory.swapTotalBytes)),
            ("Disk read", Formatters.rate(snapshot.disk.bytesPerSecondIn)),
            ("Disk write", Formatters.rate(snapshot.disk.bytesPerSecondOut)),
            ("Network down", Formatters.rate(snapshot.network.bytesPerSecondIn)),
            ("Network up", Formatters.rate(snapshot.network.bytesPerSecondOut)),
            ("Thermal state", snapshot.thermal.description),
            ("Uptime", Formatters.duration(snapshot.uptime)),
            ("Low power mode", snapshot.lowPowerMode ? "On" : "Off"),
        ] + batteryRows(snapshot)

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], spacing: 8) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.1)
                        .monospacedDigit()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
    }

    private func batteryRows(_ snapshot: SystemSnapshot) -> [(String, String)] {
        guard let battery = snapshot.battery else { return [("Battery", "Unavailable")] }
        return [
            ("Battery", "\(battery.percent)%"),
            ("Charging", battery.isCharging ? "Yes" : "No"),
            ("Power source", battery.isOnAC ? "AC" : "Battery"),
        ]
    }

    private static func pressureLabel(_ level: MemoryPressureLevel) -> String {
        switch level {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .urgent: return "Urgent"
        case .critical: return "Critical"
        case .unknown: return "Unavailable"
        }
    }

    private var processTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Processes")
                .font(.headline)
            Table(session.processes.sorted { $0.cpuPercent > $1.cpuPercent }) {
                TableColumn("PID") { process in
                    Text("\(process.id)")
                        .monospacedDigit()
                }
                .width(min: 50, ideal: 60)
                TableColumn("Name") { process in
                    Text(process.name).lineLimit(1)
                }
                TableColumn("CPU %") { process in
                    Text(Formatters.percent(process.cpuPercent)).monospacedDigit()
                }
                .width(min: 60, ideal: 70)
                TableColumn("RSS") { process in
                    Text(Formatters.bytes(process.residentBytes)).monospacedDigit()
                }
                .width(min: 80, ideal: 100)
            }
            .frame(height: 400)
        }
    }
}

extension ProcessInfo.ThermalState {
    var description: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
