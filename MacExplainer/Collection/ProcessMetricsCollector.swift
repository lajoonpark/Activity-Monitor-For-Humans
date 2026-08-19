import AppKit
import Darwin
import Foundation

struct ProcessCPUSample: Equatable {
    let pid: Int32
    let totalTicks: UInt64
}

enum CPUPercent {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Fraction of one core (as a percentage) used by `current` since `previous`.
    /// Returns nil when there is no baseline or the interval is unusable.
    static func percent(previous: ProcessCPUSample?, current: ProcessCPUSample, interval: TimeInterval) -> Double? {
        guard let previous, interval > 0, current.totalTicks >= previous.totalTicks else { return nil }
        let delta = current.totalTicks - previous.totalTicks
        let seconds = (Double(delta) * Double(timebase.numer)) / (Double(timebase.denom) * 1_000_000_000)
        let coresUsed = seconds / interval
        return min(max(coresUsed * 100, 0), 100)
    }
}

final class ProcessMetricsCollector: @unchecked Sendable {
    private struct RawSample {
        let pid: Int32
        let userTicks: UInt64
        let systemTicks: UInt64
        let residentBytes: UInt64
        let path: String
    }

    private var previousSamples: [Int32: ProcessCPUSample] = [:]
    private var previousTime: Date?

    /// Returns nil on the first call so the caller can discard the baseline sample.
    func processSnapshots(now: Date) -> [ProcessSnapshot]? {
        let current = Self.collectRawSamples()
        defer {
            previousSamples = Dictionary(uniqueKeysWithValues: current.map {
                ($0.pid, ProcessCPUSample(pid: $0.pid, totalTicks: $0.userTicks + $0.systemTicks))
            })
            previousTime = now
        }
        guard let previousTime, !previousSamples.isEmpty else { return nil }
        let interval = now.timeIntervalSince(previousTime)
        guard interval > 0 else { return nil }

        return current.map { raw in
            let previous = previousSamples[raw.pid]
            let currentSample = ProcessCPUSample(pid: raw.pid, totalTicks: raw.userTicks + raw.systemTicks)
            let percent = CPUPercent.percent(previous: previous, current: currentSample, interval: interval) ?? 0
            let app = NSRunningApplication(processIdentifier: raw.pid)
            return ProcessSnapshot(
                id: raw.pid,
                name: app?.localizedName ?? Self.pathBaseName(raw.path),
                bundleIdentifier: app?.bundleIdentifier,
                cpuPercent: percent,
                residentBytes: raw.residentBytes,
                footprintBytes: nil,
                energyNanojoulesDelta: nil,
                isApplication: app?.activationPolicy == .regular
            )
        }
    }

    private static func collectRawSamples() -> [RawSample] {
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }
        var buffer = [Int32](repeating: 0, count: Int(bufferSize))
        let count = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &buffer, bufferSize)
        guard count > 0 else { return [] }

        var samples: [RawSample] = []
        samples.reserveCapacity(Int(count))
        for i in 0..<Int(count) {
            let pid = buffer[i]
            guard pid > 0 else { continue }
            guard let info = taskInfo(for: pid) else { continue }
            let path = executablePath(for: pid)
            samples.append(RawSample(
                pid: pid,
                userTicks: info.pti_total_user,
                systemTicks: info.pti_total_system,
                residentBytes: info.pti_resident_size,
                path: path
            ))
        }
        return samples
    }

    private static func taskInfo(for pid: Int32) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(MemoryLayout<proc_taskinfo>.size))
        guard size == MemoryLayout<proc_taskinfo>.size else { return nil }
        return info
    }

    private static func executablePath(for pid: Int32) -> String {
        var path = [CChar](repeating: 0, count: 4096)
        let size = proc_pidpath(pid, &path, UInt32(path.count))
        guard size > 0, let string = String(validatingUTF8: path) else { return "" }
        return string
    }

    private static func pathBaseName(_ path: String) -> String {
        if path.isEmpty { return "System process" }
        return (path as NSString).lastPathComponent
    }
}
