import Foundation

enum MemoryPressureLevel: Int, Sendable {
    case normal = 0
    case warning = 1
    case urgent = 2
    case critical = 4
    case unknown = -1
}

struct MemoryCounters: Sendable, Equatable {
    var physicalBytes: UInt64
    var freeBytes: UInt64
    var activeBytes: UInt64
    var inactiveBytes: UInt64
    var wiredBytes: UInt64
    var compressedBytes: UInt64
    var internalBytes: UInt64
    var externalBytes: UInt64
    var purgeableBytes: UInt64
    var swapUsedBytes: UInt64
    var swapTotalBytes: UInt64
    var swapins: UInt64
    var swapouts: UInt64
    var pressure: MemoryPressureLevel
}

struct CPUCounters: Sendable, Equatable {
    var userPercent: Double
    var systemPercent: Double
    var idlePercent: Double
    var totalUsedPercent: Double
}

struct IORate: Sendable, Equatable {
    var bytesPerSecondIn: UInt64
    var bytesPerSecondOut: UInt64
}

struct BatteryInfo: Sendable, Equatable {
    var percent: Int
    var isCharging: Bool
    var isOnAC: Bool
}

struct SystemSnapshot: Sendable, Equatable {
    var timestamp: Date
    var uptime: TimeInterval
    var cpu: CPUCounters
    var memory: MemoryCounters
    var disk: IORate
    var network: IORate
    var thermal: ProcessInfo.ThermalState
    var battery: BatteryInfo?
    var lowPowerMode: Bool
}

struct ProcessSnapshot: Sendable, Equatable, Identifiable {
    var id: Int32
    var name: String
    var bundleIdentifier: String?
    var parentPid: Int32?
    var cpuPercent: Double
    var residentBytes: UInt64
    var footprintBytes: UInt64?
    var energyNanojoulesDelta: UInt64?
    var isApplication: Bool
}

struct ProcessGroupStats: Sendable, Equatable, Identifiable {
    var id: String
    var name: String
    var pid: Int32?
    var isApplication: Bool
    var cpuPercent: Double
    var residentBytes: UInt64
    var energyNanojoulesDelta: UInt64?
    var processCount: Int32
}

extension MemoryCounters {
    /// Shared definition of RAM "in use": physical minus free. Used by the popup,
    /// the menu bar label, and the Overview so they cannot drift.
    var usedBytes: UInt64 {
        physicalBytes > freeBytes ? physicalBytes - freeBytes : 0
    }

    var usedFraction: Double {
        guard physicalBytes > 0 else { return 0 }
        return min(Double(usedBytes) / Double(physicalBytes), 1)
    }
}

enum HealthLevel: String, Sendable {
    case normal
    case moderateLoad
    case highLoad
    case potentialProblem
}

struct HealthSignals: Sendable, Equatable {
    var cpuSustainedHigh: Bool
    var memoryPressureElevated: Bool
    var swapGrowing: Bool
    var thermalElevated: Bool
    var diskBusy: Bool
    var dominantProcess: ProcessSnapshot?
}

struct HealthReason: Sendable, Equatable, Identifiable {
    var id: String
    var headline: String
    var detail: String
}

struct InterpretedHealth: Sendable, Equatable {
    var level: HealthLevel
    var summary: String
    var reasons: [HealthReason]
    var signals: HealthSignals
}

struct HistoryPoint: Sendable, Equatable, Identifiable {
    var id: Date { timestamp }
    var timestamp: Date
    var cpuUsedPercent: Double
    var pressureRaw: Int
    var swapUsedBytes: UInt64
    var diskBytesPerSecond: UInt64
    var networkBytesPerSecond: UInt64
}

enum HistoryWindow: TimeInterval, CaseIterable, Sendable {
    case fiveMinutes = 300
    case thirtyMinutes = 1800
    case twoHours = 7200

    var bucketInterval: TimeInterval {
        switch self {
        case .fiveMinutes: return 0
        case .thirtyMinutes: return 10
        case .twoHours: return 30
        }
    }

    var title: String {
        switch self {
        case .fiveMinutes: return "5 min"
        case .thirtyMinutes: return "30 min"
        case .twoHours: return "2 hours"
        }
    }
}

enum MeasurementState: Sendable {
    case idle
    case measuring
    case active
}
