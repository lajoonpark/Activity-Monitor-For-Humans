import Darwin

struct SwapUsage: Equatable {
    var usedBytes: UInt64
    var availableBytes: UInt64
    var totalBytes: UInt64
    var pageSize: UInt32
    var encrypted: Bool
}

enum Sysctl {
    static func int(_ name: String) -> Int? {
        var value: Int = 0
        var size = MemoryLayout<Int>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    static func swapUsage() -> SwapUsage? {
        var raw = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &raw, &size, nil, 0) == 0 else { return nil }
        return SwapUsage(
            usedBytes: raw.xsu_used,
            availableBytes: raw.xsu_avail,
            totalBytes: raw.xsu_total,
            pageSize: raw.xsu_pagesize,
            encrypted: raw.xsu_encrypted != 0
        )
    }

    static func memoryPressureLevel() -> MemoryPressureLevel {
        var raw: Int32 = -1
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &raw, &size, nil, 0) == 0 else {
            return .unknown
        }
        return MemoryPressureLevel(rawValue: Int(raw)) ?? .unknown
    }
}
