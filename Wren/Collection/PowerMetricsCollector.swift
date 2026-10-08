import AppKit
import Foundation
import IOKit
import IOKit.ps

final class PowerMetricsCollector: @unchecked Sendable {
    func read() -> (thermal: ProcessInfo.ThermalState, lowPowerMode: Bool, battery: BatteryInfo?) {
        let processInfo = ProcessInfo.processInfo
        return (processInfo.thermalState, processInfo.isLowPowerModeEnabled, Self.readBatteryInfo())
    }

    static func readBatteryInfo() -> BatteryInfo? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { continue }
            let state = description[kIOPSPowerSourceStateKey] as? String
            let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            let current = (description[kIOPSCurrentCapacityKey] as? Int) ?? 0
            let maximum = (description[kIOPSMaxCapacityKey] as? Int) ?? 0
            let percent = maximum > 0 ? Int((Double(current) / Double(maximum)) * 100) : 0
            return BatteryInfo(
                percent: min(max(percent, 0), 100),
                isCharging: isCharging,
                isOnAC: state == kIOPSACPowerValue
            )
        }
        return nil
    }
}
