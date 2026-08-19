import Foundation

final class MetricsHistoryStore: @unchecked Sendable {
    private struct Aggregate {
        var start: Date
        var sumCPU: Double = 0
        var sumPressure: Int = 0
        var sumSwap: UInt64 = 0
        var sumDisk: UInt64 = 0
        var sumNetwork: UInt64 = 0
        var count: Int = 0
    }

    private let lock = NSLock()
    private var fiveMinutePoints: [HistoryPoint] = []
    private var thirtyMinutePoints: [HistoryPoint] = []
    private var twoHourPoints: [HistoryPoint] = []
    private var pendingAggregates: [HistoryWindow: Aggregate] = [:]

    func append(_ point: HistoryPoint) {
        lock.lock()
        defer { lock.unlock() }
        append(point, to: .fiveMinutes)
        append(point, to: .thirtyMinutes)
        append(point, to: .twoHours)
        prune()
    }

    func points(for window: HistoryWindow) -> [HistoryPoint] {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = Date().addingTimeInterval(-window.rawValue)
        switch window {
        case .fiveMinutes:
            return fiveMinutePoints.filter { $0.timestamp >= cutoff }
        case .thirtyMinutes:
            return thirtyMinutePoints.filter { $0.timestamp >= cutoff }
        case .twoHours:
            return twoHourPoints.filter { $0.timestamp >= cutoff }
        }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        fiveMinutePoints.removeAll()
        thirtyMinutePoints.removeAll()
        twoHourPoints.removeAll()
        pendingAggregates.removeAll()
    }

    private func append(_ point: HistoryPoint, to window: HistoryWindow) {
        let bucketInterval = window.bucketInterval
        if bucketInterval == 0 {
            switch window {
            case .fiveMinutes: fiveMinutePoints.append(point)
            case .thirtyMinutes: thirtyMinutePoints.append(point)
            case .twoHours: twoHourPoints.append(point)
            }
            return
        }

        var aggregate = pendingAggregates[window]
        if var agg = aggregate {
            if point.timestamp.timeIntervalSince(agg.start) >= bucketInterval {
                let finished = finalize(agg)
                switch window {
                case .fiveMinutes: fiveMinutePoints.append(finished)
                case .thirtyMinutes: thirtyMinutePoints.append(finished)
                case .twoHours: twoHourPoints.append(finished)
                }
                agg = Aggregate(start: point.timestamp)
            }
            add(point, to: &agg)
            aggregate = agg
        } else {
            var agg = Aggregate(start: point.timestamp)
            add(point, to: &agg)
            aggregate = agg
        }
        pendingAggregates[window] = aggregate
    }

    private func add(_ point: HistoryPoint, to aggregate: inout Aggregate) {
        aggregate.sumCPU += point.cpuUsedPercent
        aggregate.sumPressure += point.pressureRaw
        aggregate.sumSwap += point.swapUsedBytes
        aggregate.sumDisk += point.diskBytesPerSecond
        aggregate.sumNetwork += point.networkBytesPerSecond
        aggregate.count += 1
    }

    private func finalize(_ aggregate: Aggregate) -> HistoryPoint {
        let count = max(aggregate.count, 1)
        return HistoryPoint(
            timestamp: aggregate.start,
            cpuUsedPercent: aggregate.sumCPU / Double(count),
            pressureRaw: Int((Double(aggregate.sumPressure) / Double(count)).rounded()),
            swapUsedBytes: aggregate.sumSwap / UInt64(count),
            diskBytesPerSecond: aggregate.sumDisk / UInt64(count),
            networkBytesPerSecond: aggregate.sumNetwork / UInt64(count)
        )
    }

    private func prune() {
        let now = Date()
        fiveMinutePoints = fiveMinutePoints.filter { now.timeIntervalSince($0.timestamp) <= HistoryWindow.fiveMinutes.rawValue }
        thirtyMinutePoints = thirtyMinutePoints.filter { now.timeIntervalSince($0.timestamp) <= HistoryWindow.thirtyMinutes.rawValue }
        twoHourPoints = twoHourPoints.filter { now.timeIntervalSince($0.timestamp) <= HistoryWindow.twoHours.rawValue }
        for (window, aggregate) in pendingAggregates {
            if now.timeIntervalSince(aggregate.start) > HistoryWindow.twoHours.rawValue {
                pendingAggregates[window] = nil
            }
        }
    }
}
