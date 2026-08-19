import Darwin
import Foundation
import IOKit

final class IOMetricsCollector: @unchecked Sendable {
    private var previousDiskTotal: UInt64?
    private var previousNetworkTotal: (inbound: UInt64, outbound: UInt64)?
    private var previousTime: Date?

    /// Returns nil on the first call so the caller can discard the baseline sample.
    func diskRate(at now: Date) -> IORate? {
        let current = Self.readDiskBytesTotal()
        defer {
            previousDiskTotal = current
            previousTime = now
        }
        guard let previous = previousDiskTotal, let previousTime else { return nil }
        let interval = now.timeIntervalSince(previousTime)
        guard interval > 0 else { return nil }
        let delta = current >= previous ? current - previous : 0
        let perSecond = UInt64(Double(delta) / interval)
        return IORate(bytesPerSecondIn: perSecond, bytesPerSecondOut: 0)
    }

    /// Returns nil on the first call so the caller can discard the baseline sample.
    func networkRate(at now: Date) -> IORate? {
        let current = Self.readNetworkTotals()
        defer {
            previousNetworkTotal = current
            previousTime = now
        }
        guard let previous = previousNetworkTotal, let previousTime else { return nil }
        let interval = now.timeIntervalSince(previousTime)
        guard interval > 0 else { return nil }
        let inbound = Self.wrapDelta(current: current.inbound, previous: previous.inbound)
        let outbound = Self.wrapDelta(current: current.outbound, previous: previous.outbound)
        return IORate(
            bytesPerSecondIn: UInt64(Double(inbound) / interval),
            bytesPerSecondOut: UInt64(Double(outbound) / interval)
        )
    }

    private static func wrapDelta(current: UInt64, previous: UInt64) -> UInt64 {
        if current >= previous { return current - previous }
        return current + (1 << 32) - previous
    }

    private static func readDiskBytesTotal() -> UInt64 {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else { return 0 }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        var total: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let property = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                let read = (property["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                let written = (property["Bytes (Written)"] as? NSNumber)?.uint64Value ?? 0
                total += read + written
            }
            service = IOIteratorNext(iterator)
        }
        return total
    }

    private static func readNetworkTotals() -> (inbound: UInt64, outbound: UInt64) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return (0, 0) }
        defer { freeifaddrs(ifaddrPtr) }

        var inbound: UInt64 = 0
        var outbound: UInt64 = 0
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = current {
            let entry = cur.pointee
            if let data = entry.ifa_data {
                let family = entry.ifa_addr.map { Int32($0.pointee.sa_family) } ?? -1
                let name = entry.ifa_name.map { String(cString: $0) } ?? ""
                if family == AF_LINK, name != "lo0" {
                    let ifData = data.bindMemory(to: if_data.self, capacity: 1)
                    inbound += UInt64(ifData.pointee.ifi_ibytes)
                    outbound += UInt64(ifData.pointee.ifi_obytes)
                }
            }
            current = entry.ifa_next
        }
        return (inbound, outbound)
    }
}
