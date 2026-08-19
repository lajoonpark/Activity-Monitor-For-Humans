import Charts
import SwiftUI

struct ChartCard<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

struct CPUHistoryChart: View {
    let points: [HistoryPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Time", point.timestamp), y: .value("CPU", point.cpuUsedPercent))
                .foregroundStyle(.blue)
                .interpolationMethod(.monotone)
            AreaMark(x: .value("Time", point.timestamp), y: .value("CPU", point.cpuUsedPercent))
                .foregroundStyle(.blue.opacity(0.15))
                .interpolationMethod(.monotone)
        }
        .chartYScale(domain: 0...100)
        .chartYAxisLabel("CPU %")
    }
}

struct PressureHistoryChart: View {
    let points: [HistoryPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Time", point.timestamp), y: .value("Pressure", point.pressureRaw))
                .foregroundStyle(.purple)
                .interpolationMethod(.stepEnd)
        }
        .chartYScale(domain: 0...4)
        .chartYAxis {
            AxisMarks(values: [0, 1, 2, 4]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(Int.self) {
                        Text(label(for: raw))
                    }
                }
            }
        }
    }

    private func label(for raw: Int) -> String {
        switch raw {
        case 1: return "Warn"
        case 2: return "Urgent"
        case 4: return "Critical"
        default: return "Normal"
        }
    }
}

struct HistoryView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Period", selection: Binding(
                get: { session.selectedWindow },
                set: { session.selectWindow($0) }
            )) {
                ForEach(HistoryWindow.allCases, id: \.self) { window in
                    Text(window.title).tag(window)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ChartCard("CPU") {
                        CPUHistoryChart(points: session.historyPoints)
                            .frame(height: 120)
                    }
                    ChartCard("Memory pressure") {
                        PressureHistoryChart(points: session.historyPoints)
                            .frame(height: 120)
                    }
                    ChartCard("Swap") {
                        SwapHistoryChart(points: session.historyPoints)
                            .frame(height: 120)
                    }
                    ChartCard("Disk activity") {
                        ThroughputChart(points: session.historyPoints, keyPath: \.diskBytesPerSecond, color: .orange)
                            .frame(height: 120)
                    }
                    ChartCard("Network activity") {
                        ThroughputChart(points: session.historyPoints, keyPath: \.networkBytesPerSecond, color: .teal)
                            .frame(height: 120)
                    }
                }
            }
        }
        .padding()
    }
}

private struct SwapHistoryChart: View {
    let points: [HistoryPoint]

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Time", point.timestamp), y: .value("Swap", point.swapUsedBytes))
                .foregroundStyle(.pink.opacity(0.15))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Time", point.timestamp), y: .value("Swap", point.swapUsedBytes))
                .foregroundStyle(.pink)
                .interpolationMethod(.monotone)
        }
        .chartYAxisLabel("Swap used")
    }
}

private struct ThroughputChart: View {
    let points: [HistoryPoint]
    let keyPath: KeyPath<HistoryPoint, UInt64>
    let color: Color

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Time", point.timestamp), y: .value("Rate", point[keyPath: keyPath]))
                .foregroundStyle(color.opacity(0.15))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Time", point.timestamp), y: .value("Rate", point[keyPath: keyPath]))
                .foregroundStyle(color)
                .interpolationMethod(.monotone)
        }
        .chartYAxisLabel("Per second")
    }
}
