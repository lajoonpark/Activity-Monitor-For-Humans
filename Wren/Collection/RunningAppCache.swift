import AppKit
import Foundation

/// Resolves `NSRunningApplication` once per process instead of once per tick,
/// and once per view render instead of once per layout pass.
///
/// Both the lookup and the icon extraction are expensive relative to the
/// sample period, and neither changes for the life of a process:
/// `NSRunningApplication(processIdentifier:)` scans the LaunchServices
/// registration, `localizedName` makes a synchronous XPC round-trip to
/// LaunchServices, and `icon` reads file metadata off disk — all on the main
/// thread. The cache therefore resolves each PID at most once and ages entries
/// out only after they have been unseen for a while.
///
/// Ageing out matters because macOS recycles PIDs: a stale entry could
/// otherwise describe an unrelated app. Evicting on every sample was the wrong
/// trade — the top-of-list pools churn constantly (transient workers enter and
/// leave), so per-sample eviction re-paid the full resolution cost for
/// returning PIDs on nearly every tick. Five minutes bounds the PID-reuse risk
/// while keeping re-resolution rare.
@MainActor
final class RunningAppCache {
    struct Entry {
        var localizedName: String?
        var bundleIdentifier: String?
        var isApplication: Bool
    }

    static let shared = RunningAppCache()

    private struct Slot {
        /// Resolved metadata, or nil when the PID has no `NSRunningApplication`.
        var entry: Entry?
        /// Resolved lazily — only the rows that actually draw an icon ask for one.
        var icon: NSImage?
        var lastSeen: Date
    }

    private static let lifetime: TimeInterval = 300

    private var cache: [Int32: Slot] = [:]

    /// Metadata only — never touches the icon, so this is safe to call for
    /// every process in a sample batch on the main thread.
    func entry(for pid: Int32) -> Entry? {
        guard pid > 0 else { return nil }
        let now = Date()
        if let slot = cache[pid] {
            cache[pid]?.lastSeen = now
            return slot.entry
        }
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            cache[pid] = Slot(entry: nil, icon: nil, lastSeen: now)
            return nil
        }
        let entry = Entry(
            localizedName: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            isApplication: app.activationPolicy == .regular
        )
        cache[pid] = Slot(entry: entry, icon: nil, lastSeen: now)
        return entry
    }

    /// The process icon, resolved at most once per process and only when a view
    /// actually draws it. PIDs already known to have no application never hit
    /// LaunchServices again.
    func icon(for pid: Int32) -> NSImage? {
        guard pid > 0 else { return nil }
        if let slot = cache[pid] {
            if let icon = slot.icon { return icon }
            guard slot.entry != nil else { return nil }
        }
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            if cache[pid] == nil {
                cache[pid] = Slot(entry: nil, icon: nil, lastSeen: Date())
            }
            return nil
        }
        let icon = app.icon
        let now = Date()
        if var slot = cache[pid] {
            slot.icon = icon
            slot.lastSeen = now
            cache[pid] = slot
        } else {
            cache[pid] = Slot(
                entry: Entry(
                    localizedName: app.localizedName,
                    bundleIdentifier: app.bundleIdentifier,
                    isApplication: app.activationPolicy == .regular
                ),
                icon: icon,
                lastSeen: now
            )
        }
        return icon
    }

    /// Drops entries that have not been seen for `lifetime`. Callers keep the
    /// cache warm simply by asking for the PIDs they display.
    func prune() {
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.lastSeen) <= Self.lifetime }
    }
}
