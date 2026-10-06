import Charts
import SwiftUI

struct HistoryView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if session.historyPoints.isEmpty {
                    emptyState
                } else {
                    ChartCard(title: "Processor use", entry: MetricGlossary.cpu, note: "How busy your Mac has been. Spikes are normal; a line that stays near the top is worth a look.") {
                        CPUHistoryChart(points: session.historyPoints)
                            .frame(height: 130)
                    }
                    ChartCard(title: "Memory pressure", entry: MetricGlossary.memoryPressure, note: "The measure that actually matters for memory. As long as it stays near the bottom, your Mac has room.") {
                        PressureHistoryChart(points: session.historyPoints)
                            .frame(height: 130)
                    }
                    ChartCard(title: "Disk-backed memory (swap)", entry: MetricGlossary.swap, note: "Data macOS parked on your disk because RAM was busy. A flat line is fine; a steep climb means your Mac is short on memory.") {
                        SwapHistoryChart(points: session.historyPoints)
                            .frame(height: 130)
                    }
                    ChartCard(title: "Disk activity", entry: MetricGlossary.diskRead, note: "Files being read and written. Bursts usually mean something is opening, saving or being indexed.") {
                        ThroughputChart(points: session.historyPoints, keyPath: \.diskBytesPerSecond, tint: Palette.accent)
                            .frame(height: 130)
                    }
                    ChartCard(title: "Network activity", entry: MetricGlossary.networkDown, note: "Data coming in and going out. A hump here is usually a download, a call or a backup.") {
                        ThroughputChart(points: session.historyPoints, keyPath: \.networkBytesPerSecond, tint: Palette.accent)
                            .frame(height: 130)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .animation(Motion.respecting(Motion.drift, reduceMotion: reduceMotion), value: session.selectedWindow)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(title: "History")
            HStack {
                Picker("Period", selection: Binding(
                    get: { session.selectedWindow },
                    set: { session.selectWindow($0) }
                )) {
                    ForEach(HistoryWindow.allCases, id: \.self) { window in
                        Text(window.title).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                Spacer()
                Text(periodNote)
                    .font(Typeface.prose(12.5))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private var periodNote: String {
        switch session.selectedWindow {
        case .fiveMinutes: return "Every reading, as it happened."
        case .thirtyMinutes: return "Averaged over ten-second windows."
        case .twoHours: return "Averaged over thirty-second windows."
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not enough history yet.")
                .font(Typeface.proseEmphasis(16))
                .foregroundStyle(Palette.ink)
            Text("Charts appear once your Mac has been watched for a few minutes. Leave the app open and they will fill in.")
                .font(Typeface.prose(13.5))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .paperCard()
    }
}

// MARK: - Card

private struct ChartCard<Content: View>: View {
    let title: String
    let entry: GlossaryEntry
    let note: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                GlossaryLabel(entry: entry, title: title, font: Typeface.heading(13.5), tint: Palette.ink)
                Spacer()
            }
            content
            Text(note)
                .font(Typeface.prose(11.5))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .paperCard()
    }
}

// MARK: - Traces

struct CPUHistoryChart: View {
    let points: [HistoryPoint]

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Time", point.timestamp), y: .value("CPU", point.cpuUsedPercent))
                .foregroundStyle(
                    LinearGradient(colors: [Palette.accent.opacity(0.22), Palette.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)
            LineMark(x: .value("Time", point.timestamp), y: .value("CPU", point.cpuUsedPercent))
                .foregroundStyle(Palette.accent)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .interpolationMethod(.monotone)
            RuleMark(y: .value("Busy", 80))
                .foregroundStyle(Palette.health(.highLoad).opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine().foregroundStyle(Palette.rule)
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text("\(Int(raw))%")
                            .font(Typeface.label(9.5))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Palette.rule.opacity(0.6))
                AxisValueLabel()
                    .font(Typeface.label(9.5))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }
}

struct PressureHistoryChart: View {
    let points: [HistoryPoint]

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Time", point.timestamp), y: .value("Pressure", point.pressureRaw))
                .foregroundStyle(
                    LinearGradient(colors: [Palette.accent.opacity(0.2), Palette.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.stepEnd)
            LineMark(x: .value("Time", point.timestamp), y: .value("Pressure", point.pressureRaw))
                .foregroundStyle(Palette.accent)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .interpolationMethod(.stepEnd)
            RuleMark(y: .value("Warn", 1))
                .foregroundStyle(Palette.health(.moderateLoad).opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            RuleMark(y: .value("Urgent", 2))
                .foregroundStyle(Palette.health(.highLoad).opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYScale(domain: 0...4)
        .chartYAxis {
            AxisMarks(values: [0, 1, 2, 4]) { value in
                AxisGridLine().foregroundStyle(Palette.rule)
                AxisValueLabel {
                    if let raw = value.as(Int.self) {
                        Text(label(for: raw))
                            .font(Typeface.label(9.5))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Palette.rule.opacity(0.6))
                AxisValueLabel()
                    .font(Typeface.label(9.5))
                    .foregroundStyle(Palette.inkSoft)
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

private struct SwapHistoryChart: View {
    let points: [HistoryPoint]

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Time", point.timestamp), y: .value("Swap", point.swapUsedBytes))
                .foregroundStyle(
                    LinearGradient(colors: [Palette.accent.opacity(0.18), Palette.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)
            LineMark(x: .value("Time", point.timestamp), y: .value("Swap", point.swapUsedBytes))
                .foregroundStyle(Palette.accent)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .interpolationMethod(.monotone)
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Palette.rule)
                AxisValueLabel {
                    if let raw = value.as(UInt64.self) {
                        Text(Formatters.bytes(raw))
                            .font(Typeface.label(9.5))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Palette.rule.opacity(0.6))
                AxisValueLabel()
                    .font(Typeface.label(9.5))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }
}

private struct ThroughputChart: View {
    let points: [HistoryPoint]
    let keyPath: KeyPath<HistoryPoint, UInt64>
    let tint: Color

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Time", point.timestamp), y: .value("Rate", point[keyPath: keyPath]))
                .foregroundStyle(
                    LinearGradient(colors: [tint.opacity(0.2), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)
            LineMark(x: .value("Time", point.timestamp), y: .value("Rate", point[keyPath: keyPath]))
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .interpolationMethod(.monotone)
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Palette.rule)
                AxisValueLabel {
                    if let raw = value.as(UInt64.self) {
                        Text(Formatters.rate(raw))
                            .font(Typeface.label(9.5))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Palette.rule.opacity(0.6))
                AxisValueLabel()
                    .font(Typeface.label(9.5))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }
}
