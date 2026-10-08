import Darwin
import Foundation

final class SystemMetricsCollector: @unchecked Sendable {
    private var previousLoad: host_cpu_load_info?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private let pressureLock = NSLock()
    private var pressureEvent: MemoryPressureLevel?

    init() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: nil)
        source.setEventHandler { [weak self] in
            let flags = source.data
            let level: MemoryPressureLevel = flags.contains(.critical) ? .critical : .warning
            guard let self else { return }
            self.pressureLock.lock()
            self.pressureEvent = level
            self.pressureLock.unlock()
        }
        source.resume()
        memoryPressureSource = source
    }

    var physicalMemoryBytes: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    /// Returns nil on the first call so the caller can discard the baseline sample.
    func cpuCounters() -> CPUCounters? {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        defer { previousLoad = load }
        guard let previous = previousLoad else { return nil }

        let user = tickDelta(current: load, previous: previous, state: CPU_STATE_USER)
        let system = tickDelta(current: load, previous: previous, state: CPU_STATE_SYSTEM)
        let idle = tickDelta(current: load, previous: previous, state: CPU_STATE_IDLE)
        let nice = tickDelta(current: load, previous: previous, state: CPU_STATE_NICE)

        let total = max(user + system + idle + nice, 1)
        let userPercent = Double(user) / Double(total) * 100
        let systemPercent = Double(system) / Double(total) * 100
        let nicePercent = Double(nice) / Double(total) * 100
        let idlePercent = Double(idle) / Double(total) * 100
        let used = min(max(userPercent + systemPercent + nicePercent, 0), 100)
        return CPUCounters(
            userPercent: min(max(userPercent, 0), 100),
            systemPercent: min(max(systemPercent + nicePercent, 0), 100),
            idlePercent: min(max(idlePercent, 0), 100),
            totalUsedPercent: used
        )
    }

    func memoryCounters() -> MemoryCounters {
        let physical = physicalMemoryBytes
        var free: UInt64 = 0
        var active: UInt64 = 0
        var inactive: UInt64 = 0
        var wired: UInt64 = 0
        var compressed: UInt64 = 0
        var internalBytes: UInt64 = 0
        var externalBytes: UInt64 = 0
        var purgeable: UInt64 = 0
        var swapins: UInt64 = 0
        var swapouts: UInt64 = 0

        if let (stats, pageSize) = MachVM.readVMStatistics() {
            free = UInt64(stats.free_count) * pageSize
            active = UInt64(stats.active_count) * pageSize
            inactive = UInt64(stats.inactive_count) * pageSize
            wired = UInt64(stats.wire_count) * pageSize
            compressed = UInt64(stats.compressor_page_count) * pageSize
            internalBytes = UInt64(stats.internal_page_count) * pageSize
            externalBytes = UInt64(stats.external_page_count) * pageSize
            purgeable = UInt64(stats.purgeable_count) * pageSize
            swapins = UInt64(stats.swapins)
            swapouts = UInt64(stats.swapouts)
        }

        let swap = Sysctl.swapUsage()
        pressureLock.lock()
        let eventLevel = pressureEvent
        pressureLock.unlock()

        let pressure = Sysctl.memoryPressureLevel()
        let combinedPressure: MemoryPressureLevel
        if pressure == .normal, let eventLevel, eventLevel != .normal {
            combinedPressure = eventLevel
        } else {
            combinedPressure = pressure
        }

        return MemoryCounters(
            physicalBytes: physical,
            freeBytes: free,
            activeBytes: active,
            inactiveBytes: inactive,
            wiredBytes: wired,
            compressedBytes: compressed,
            internalBytes: internalBytes,
            externalBytes: externalBytes,
            purgeableBytes: purgeable,
            swapUsedBytes: swap?.usedBytes ?? 0,
            swapTotalBytes: swap?.totalBytes ?? 0,
            swapins: swapins,
            swapouts: swapouts,
            pressure: combinedPressure
        )
    }

    private func tickDelta(current: host_cpu_load_info, previous: host_cpu_load_info, state: Int32) -> UInt64 {
        func value(_ load: host_cpu_load_info) -> UInt64 {
            switch state {
            case CPU_STATE_USER: return UInt64(load.cpu_ticks.0)
            case CPU_STATE_SYSTEM: return UInt64(load.cpu_ticks.1)
            case CPU_STATE_IDLE: return UInt64(load.cpu_ticks.2)
            default: return UInt64(load.cpu_ticks.3)
            }
        }
        let now = value(current)
        let then = value(previous)
        return now > then ? now - then : 0
    }
}
