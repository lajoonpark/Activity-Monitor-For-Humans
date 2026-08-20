import Foundation
import Observation

struct MetricsBatch: Sendable {
    let snapshot: SystemSnapshot
    let processes: [ProcessSnapshot]
    let interpreted: InterpretedHealth
}

@MainActor
@Observable
final class AppSession {
    var state: MeasurementState = .idle
    var current: SystemSnapshot?
    var processes: [ProcessSnapshot] = []
    var appGroups: [ProcessGroupStats] = []
    var interpreted: InterpretedHealth?
    var historyPoints: [HistoryPoint] = []
    var selectedWindow: HistoryWindow = .thirtyMinutes

    let preferences: AppPreferences

    private let engine = MetricsEngine()

    init(preferences: AppPreferences) {
        self.preferences = preferences
        self.selectedWindow = preferences.historyWindow
    }

    var cpuPercent: Double {
        current?.cpu.totalUsedPercent ?? 0
    }

    var usedBytes: UInt64 {
        current?.memory.usedBytes ?? 0
    }

    func start() {
        guard state == .idle else { return }
        state = .measuring
        engine.start(interval: preferences.sampleInterval) { [weak self] batch in
            Task { @MainActor [weak self] in
                self?.publish(batch)
            }
        }
    }

    func stop() {
        engine.stop()
        state = .idle
    }

    func setSampleInterval(_ interval: TimeInterval) {
        engine.setInterval(interval)
    }

    func selectWindow(_ window: HistoryWindow) {
        selectedWindow = window
        if state == .active {
            historyPoints = engine.history(for: window)
        }
    }

    private func publish(_ batch: MetricsBatch) {
        current = batch.snapshot
        processes = ProcessMetricsCollector.applyingAppMetadata(to: batch.processes)
        appGroups = ProcessGrouping.buildGroups(from: processes)
        interpreted = batch.interpreted
        historyPoints = engine.history(for: selectedWindow)
        state = .active
    }
}

/// Runs sampling on a dedicated utility queue. Owns the timer and collectors.
private final class MetricsEngine: @unchecked Sendable {
    private let queue = DispatchQueue(label: "metrics.collection", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var interval: TimeInterval = 2

    private let systemCollector = SystemMetricsCollector()
    private let ioCollector = IOMetricsCollector()
    private let powerCollector = PowerMetricsCollector()
    private let processCollector = ProcessMetricsCollector()
    private let store = MetricsHistoryStore()
    private let interpreter = HealthInterpreter()

    private var onBatch: (@Sendable (MetricsBatch) -> Void)?
    private var lastSampleTime: Date?
    private var isCollecting = false

    func start(interval: TimeInterval, onBatch: @escaping @Sendable (MetricsBatch) -> Void) {
        self.interval = interval
        self.onBatch = onBatch
        scheduleTimer(interval: interval)
    }

    func setInterval(_ interval: TimeInterval) {
        self.interval = interval
        scheduleTimer(interval: interval)
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func history(for window: HistoryWindow) -> [HistoryPoint] {
        store.points(for: window)
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.cancel()
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(100))
        source.setEventHandler { [weak self] in
            self?.tick(now: Date())
        }
        timer = source
        source.resume()
    }

    private func tick(now: Date) {
        guard !isCollecting else { return }
        isCollecting = true
        defer { isCollecting = false }

        let cpu = systemCollector.cpuCounters()
        let disk = ioCollector.diskRate(at: now)
        let network = ioCollector.networkRate(at: now)
        let processesLimit = processCollector.processSnapshots(now: now)

        guard let cpu, let disk, let network, let processesLimit else {
            lastSampleTime = now
            return
        }

        let memory = systemCollector.memoryCounters()
        let power = powerCollector.read()
        lastSampleTime = now

        let snapshot = SystemSnapshot(
            timestamp: now,
            uptime: ProcessInfo.processInfo.systemUptime,
            cpu: cpu,
            memory: memory,
            disk: disk,
            network: network,
            thermal: power.thermal,
            battery: power.battery,
            lowPowerMode: power.lowPowerMode
        )

        let processes = Self.topProcesses(from: processesLimit)

        let point = HistoryPoint(
            timestamp: now,
            cpuUsedPercent: cpu.totalUsedPercent,
            pressureRaw: memory.pressure.rawValue,
            swapUsedBytes: memory.swapUsedBytes,
            diskBytesPerSecond: disk.bytesPerSecondIn + disk.bytesPerSecondOut,
            networkBytesPerSecond: network.bytesPerSecondIn + network.bytesPerSecondOut
        )
        store.append(point)

        let fiveMinuteHistory = store.points(for: .fiveMinutes)
        let interpreted = interpreter.interpret(current: snapshot, processes: processes, history: fiveMinuteHistory)

        guard let onBatch else { return }
        onBatch(MetricsBatch(snapshot: snapshot, processes: processes, interpreted: interpreted))
    }

    /// Keep the top 25 by CPU and top 25 by RSS, merged, for presentation.
    private static func topProcesses(from all: [ProcessSnapshot]) -> [ProcessSnapshot] {
        var byCPUSet = Set<Int32>()
        var merged: [ProcessSnapshot] = []
        for process in all.sorted(by: { $0.cpuPercent > $1.cpuPercent }).prefix(25) {
            byCPUSet.insert(process.id)
            merged.append(process)
        }
        for process in all.sorted(by: { $0.residentBytes > $1.residentBytes }).prefix(25) where !byCPUSet.contains(process.id) {
            merged.append(process)
        }
        return merged
    }
}
