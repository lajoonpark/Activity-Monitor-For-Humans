import AppKit
import Foundation

/// Resolves `NSRunningApplication` once per process instead of once per tick,
/// and once per view render instead of once per layout pass.
///
/// Both the lookup and the icon extraction are expensive relative to the
/// 2-second sample period, and neither changes for the life of a process. The
/// cache is pruned against the live PID set on every sample because macOS
/// recycles PIDs, so a stale entry could otherwise describe an unrelated app.
@MainActor
final class RunningAppCache {
    struct Entry {
        var localizedName: String?
        var bundleIdentifier: String?
        var isApplication: Bool
        var icon: NSImage?
    }

    private enum Resolved {
        case app(Entry)
        /// Resolved and confirmed to have no `NSRunningApplication` — cached so
        /// the system processes are not looked up again every tick.
        case notAnApp
    }

    static let shared = RunningAppCache()

    private var cache: [Int32: Resolved] = [:]

    func entry(for pid: Int32) -> Entry? {
        guard pid > 0 else { return nil }
        if let resolved = cache[pid] {
            switch resolved {
            case .app(let entry): return entry
            case .notAnApp: return nil
            }
        }
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            cache[pid] = .notAnApp
            return nil
        }
        let entry = Entry(
            localizedName: app.localizedName,
            bundleIdentifier: app.bundleIdentifier,
            isApplication: app.activationPolicy == .regular,
            icon: app.icon
        )
        cache[pid] = .app(entry)
        return entry
    }

    /// Drops everything outside `live` so recycled PIDs are never served stale data.
    func retainOnly(_ live: Set<Int32>) {
        cache = cache.filter { live.contains($0.key) }
    }
}
