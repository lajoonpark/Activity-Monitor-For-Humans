import AppKit
import Darwin
import Foundation

struct ProcessCPUSample: Equatable {
    let pid: Int32
    let totalTicks: UInt64
}

enum EnergyDelta {
    static func nanojoules(previous: UInt64?, current: UInt64?) -> UInt64? {
        guard let previous, let current, current >= previous else { return nil }
        return current - previous
    }
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
        let parentPid: Int32?
        let energyNanojoules: UInt64?
        let path: String
    }

    private struct ProcessPreviousSample: Equatable {
        let totalTicks: UInt64
        let energyNanojoules: UInt64?
        let path: String
    }

    private var previousSamples: [Int32: ProcessPreviousSample] = [:]
    private var previousTime: Date?

    /// Returns nil on the first call so the caller can discard the baseline sample.
    func processSnapshots(now: Date) -> [ProcessSnapshot]? {
        let current = Self.collectRawSamples()
        defer {
            previousSamples = Dictionary(uniqueKeysWithValues: current.map {
                ($0.pid, ProcessPreviousSample(
                    totalTicks: $0.userTicks + $0.systemTicks,
                    energyNanojoules: $0.energyNanojoules,
                    path: $0.path
                ))
            })
            previousTime = now
        }
        guard let previousTime, !previousSamples.isEmpty else { return nil }
        let interval = now.timeIntervalSince(previousTime)
        guard interval > 0 else { return nil }

        return current.map { raw in
            let previous = previousSamples[raw.pid]
            let currentSample = ProcessCPUSample(pid: raw.pid, totalTicks: raw.userTicks + raw.systemTicks)
            let previousSample = previous.map { ProcessCPUSample(pid: raw.pid, totalTicks: $0.totalTicks) }
            let percent = CPUPercent.percent(previous: previousSample, current: currentSample, interval: interval) ?? 0
            return ProcessSnapshot(
                id: raw.pid,
                name: Self.pathBaseName(raw.path),
                bundleIdentifier: nil,
                parentPid: raw.parentPid,
                cpuPercent: percent,
                residentBytes: raw.residentBytes,
                footprintBytes: nil,
                energyNanojoulesDelta: EnergyDelta.nanojoules(previous: previous?.energyNanojoules, current: raw.energyNanojoules),
                isApplication: false
            )
        }
    }

    /// Applies AppKit metadata (display name, bundle ID, is-application) to a batch of
    /// snapshots. `NSRunningApplication` is main-thread-only and must never be called on
    /// the sampling queue — doing so blocks collection and leaves the app stuck "measuring".
    @MainActor
    static func applyingAppMetadata(to processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        processes.map { process in
            let app = NSRunningApplication(processIdentifier: process.id)
            return ProcessSnapshot(
                id: process.id,
                name: app?.localizedName ?? process.name,
                bundleIdentifier: app?.bundleIdentifier,
                parentPid: process.parentPid,
                cpuPercent: process.cpuPercent,
                residentBytes: process.residentBytes,
                footprintBytes: process.footprintBytes,
                energyNanojoulesDelta: process.energyNanojoulesDelta,
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
            guard let info = taskAllInfo(for: pid) else { continue }
            let path = executablePath(for: pid)
            samples.append(RawSample(
                pid: pid,
                userTicks: info.ptinfo.pti_total_user,
                systemTicks: info.ptinfo.pti_total_system,
                residentBytes: info.ptinfo.pti_resident_size,
                parentPid: Int32(info.pbsd.pbi_ppid),
                energyNanojoules: energyNanojoules(for: pid),
                path: path
            ))
        }
        return samples
    }

    private static func taskAllInfo(for pid: Int32) -> proc_taskallinfo? {
        var info = proc_taskallinfo()
        let size = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, Int32(MemoryLayout<proc_taskallinfo>.size))
        guard size == MemoryLayout<proc_taskallinfo>.size else { return nil }
        return info
    }

    /// Reads the process lifetime energy in nanojoules, or nil when the platform
    /// does not report it (protected processes, unsupported builds). Uses a
    /// caller-allocated struct buffer; the `void**` import style is avoided because
    /// some macOS builds return an unreadable kernel pointer from it.
    private static func energyNanojoules(for pid: Int32) -> UInt64? {
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            let slot = unsafeBitCast(pointer, to: UnsafeMutablePointer<rusage_info_t?>.self)
            return proc_pid_rusage(pid, RUSAGE_INFO_V6, slot)
        }
        guard result == 0 else { return nil }
        return info.ri_energy_nj
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
