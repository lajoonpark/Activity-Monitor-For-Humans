import Foundation

enum ExplanationGenerator {
    static func summary(for level: HealthLevel) -> String {
        switch level {
        case .normal:
            return "Your Mac is running normally."
        case .moderateLoad:
            return "Your Mac is handling a bit of extra work right now."
        case .highLoad:
            return "Your Mac is working hard."
        case .potentialProblem:
            return "Your Mac may be struggling to keep up."
        }
    }

    static func generate(level: HealthLevel, signals: HealthSignals, snapshot: SystemSnapshot) -> [HealthReason] {
        var reasons: [HealthReason] = []

        switch snapshot.memory.pressure {
        case .critical:
            reasons.append(HealthReason(
                id: "pressure.critical",
                headline: "Your Mac is under heavy memory pressure.",
                detail: "It is having trouble keeping everything in memory at once, and that can slow things down."
            ))
        case .urgent:
            reasons.append(HealthReason(
                id: "pressure.urgent",
                headline: "macOS is under memory pressure.",
                detail: "It is working to free up memory by compressing or moving data."
            ))
        case .warning:
            reasons.append(HealthReason(
                id: "pressure.warning",
                headline: "Memory pressure is elevated.",
                detail: "Your Mac is working to keep everything it needs in memory."
            ))
        case .normal:
            let workingBytes = snapshot.memory.activeBytes + snapshot.memory.wiredBytes + snapshot.memory.compressedBytes
            if snapshot.memory.physicalBytes > 0,
               Double(workingBytes) / Double(snapshot.memory.physicalBytes) > 0.7 {
                reasons.append(HealthReason(
                    id: "memory.normal.full",
                    headline: "Your Mac is using memory normally.",
                    detail: "macOS keeps recently used data in RAM on purpose, so a full memory graph is not a problem by itself."
                ))
            }
            if snapshot.memory.swapUsedBytes > 0, !signals.memoryPressureElevated {
                reasons.append(HealthReason(
                    id: "swap.normal",
                    headline: "Some memory is being stored on disk.",
                    detail: "macOS is using some disk-backed memory, but memory pressure is still normal."
                ))
            }
        case .unknown:
            break
        }

        if signals.swapGrowing {
            reasons.append(HealthReason(
                id: "swap.growing",
                headline: "Disk-backed memory is growing.",
                detail: "macOS is moving some data out of RAM, which can slow things down while it lasts."
            ))
        }

        if signals.cpuSustainedHigh {
            if let process = signals.dominantProcess {
                reasons.append(HealthReason(
                    id: "cpu.high.app",
                    headline: "\(process.name) is using a lot of CPU.",
                    detail: "It has been keeping the processor busy for a while."
                ))
            } else {
                reasons.append(HealthReason(
                    id: "cpu.high",
                    headline: "CPU usage is unusually high.",
                    detail: "The Mac has been working hard for a while."
                ))
            }
        }

        if signals.thermalElevated {
            reasons.append(HealthReason(
                id: "thermal.elevated",
                headline: "The Mac is warm.",
                detail: "It may run a little slower for a while as it cools down."
            ))
        }

        if signals.diskBusy {
            reasons.append(HealthReason(
                id: "disk.busy",
                headline: "The disk is very active.",
                detail: "A lot of files are being read or written right now."
            ))
        }

        return Array(reasons.prefix(3))
    }
}
