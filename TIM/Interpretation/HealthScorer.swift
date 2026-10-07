import Foundation

struct HealthScore: Sendable, Equatable {
    var level: HealthLevel
    var signals: HealthSignals
}

enum HealthScorer {
    static let cpuModerateThreshold: Double = 70
    static let cpuHighThreshold: Double = 85
    static let cpuExtremeThreshold: Double = 95
    static let cpuModerateDuration: TimeInterval = 20
    static let cpuHighDuration: TimeInterval = 30
    static let cpuExtremeDuration: TimeInterval = 60
    static let pressureWarningDuration: TimeInterval = 15
    static let pressureUrgentDuration: TimeInterval = 60
    static let swapGrowthSlowThreshold: UInt64 = 256 << 20
    static let swapGrowthFastThreshold: UInt64 = 1024 << 20
    static let swapGrowthWindow: TimeInterval = 60
    static let swapGrowthSlowWhileWarningDuration: TimeInterval = 30
    static let diskBusyRate: UInt64 = 400 << 20
    static let diskBusyDuration: TimeInterval = 30
    static let diskBusyWithLoadDuration: TimeInterval = 60
    static let dominantProcessCPUThreshold: Double = 30
    static let dominatingProcessCPUThreshold: Double = 50

    static func evaluate(snapshot: SystemSnapshot, processes: [ProcessSnapshot], history: [HistoryPoint]) -> HealthScore {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let candidates = processes.filter { $0.id != selfPID || $0.cpuPercent > 5 }
        let topByCPU = candidates.max { $0.cpuPercent < $1.cpuPercent }

        let pressureNow = snapshot.memory.pressure
        let pressureSustained = sustainedDuration(in: history, atLeast: MemoryPressureLevel.warning.rawValue)
        let urgentSustained = sustainedDuration(in: history, atLeast: MemoryPressureLevel.urgent.rawValue)

        let cpuModerateSustained = sustainedCPUDuration(in: history, atLeast: cpuModerateThreshold)
        let cpuHighSustained = sustainedCPUDuration(in: history, atLeast: cpuHighThreshold)
        let cpuExtremeSustained = sustainedCPUDuration(in: history, atLeast: cpuExtremeThreshold)

        let diskSustained = sustainedDiskDuration(in: history, atLeast: diskBusyRate)
        let swap = swapGrowth(in: history, window: swapGrowthWindow)

        var signals = HealthSignals(
            cpuSustainedHigh: false,
            memoryPressureElevated: false,
            swapGrowing: false,
            thermalElevated: false,
            diskBusy: false,
            dominantProcess: nil
        )

        if pressureNow != .normal && pressureNow != .unknown {
            signals.memoryPressureElevated = true
        }
        if let top = topByCPU, top.cpuPercent >= dominantProcessCPUThreshold {
            signals.dominantProcess = top
        }
        if cpuModerateSustained >= cpuModerateDuration {
            signals.cpuSustainedHigh = true
        }
        if snapshot.thermal != .nominal {
            signals.thermalElevated = true
        }

        var moderate = false
        var high = false
        var problem = false

        // Memory pressure
        if pressureNow == .critical {
            problem = true
        } else if pressureNow == .urgent || urgentSustained >= pressureUrgentDuration {
            high = true
        } else if pressureSustained >= pressureWarningDuration {
            moderate = true
        }

        // Swap growth
        if swap.grewFast, pressureNow == .urgent {
            high = true
            signals.swapGrowing = true
        } else if swap.grewSlow, pressureSustained >= swapGrowthSlowWhileWarningDuration {
            moderate = true
            signals.swapGrowing = true
        }
        if swap.grewSlow, pressureNow == .critical {
            problem = true
            signals.swapGrowing = true
        }

        // Sustained CPU
        let dominates = topByCPU.map { $0.cpuPercent >= dominatingProcessCPUThreshold } ?? false
        if cpuExtremeSustained >= cpuExtremeDuration, thermalRank(snapshot.thermal) >= 1 || dominates {
            problem = true
        } else if cpuHighSustained >= cpuHighDuration {
            high = true
        } else if cpuModerateSustained >= cpuModerateDuration {
            moderate = true
        }

        // Thermal
        switch snapshot.thermal {
        case .critical: problem = true
        case .serious: high = true
        case .fair: moderate = true
        case .nominal: break
        @unknown default: break
        }

        // Disk
        if diskSustained >= diskBusyWithLoadDuration, cpuModerateSustained >= cpuModerateDuration || pressureSustained >= pressureWarningDuration {
            high = true
            signals.diskBusy = true
        } else if diskSustained >= diskBusyDuration {
            moderate = true
            signals.diskBusy = true
        }

        let level: HealthLevel
        if problem { level = .potentialProblem }
        else if high { level = .highLoad }
        else if moderate { level = .moderateLoad }
        else { level = .normal }

        return HealthScore(level: level, signals: signals)
    }

    // MARK: - Duration helpers

    private static func thermalRank(_ state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        @unknown default: return 0
        }
    }

    private static func sustainedDuration(in history: [HistoryPoint], atLeast rawPressure: Int) -> TimeInterval {
        var duration: TimeInterval = 0
        var last: Date?
        for point in history.reversed() {
            guard point.pressureRaw >= rawPressure else { break }
            if let previous = last {
                duration += point.timestamp.distance(to: previous)
            }
            last = point.timestamp
        }
        return duration
    }

    private static func sustainedCPUDuration(in history: [HistoryPoint], atLeast threshold: Double) -> TimeInterval {
        var duration: TimeInterval = 0
        var last: Date?
        for point in history.reversed() {
            guard point.cpuUsedPercent >= threshold else { break }
            if let previous = last {
                duration += point.timestamp.distance(to: previous)
            }
            last = point.timestamp
        }
        return duration
    }

    private static func sustainedDiskDuration(in history: [HistoryPoint], atLeast threshold: UInt64) -> TimeInterval {
        var duration: TimeInterval = 0
        var last: Date?
        for point in history.reversed() {
            guard point.diskBytesPerSecond >= threshold else { break }
            if let previous = last {
                duration += point.timestamp.distance(to: previous)
            }
            last = point.timestamp
        }
        return duration
    }

    private static func swapGrowth(in history: [HistoryPoint], window: TimeInterval) -> (grewSlow: Bool, grewFast: Bool) {
        guard let newest = history.last else { return (false, false) }
        let cutoff = newest.timestamp.addingTimeInterval(-window)
        let windowed = history.filter { $0.timestamp >= cutoff }
        guard let oldest = windowed.first, windowed.count >= 2, newest.swapUsedBytes >= oldest.swapUsedBytes else {
            return (false, false)
        }
        let delta = newest.swapUsedBytes - oldest.swapUsedBytes
        return (delta >= swapGrowthSlowThreshold, delta >= swapGrowthFastThreshold)
    }
}
