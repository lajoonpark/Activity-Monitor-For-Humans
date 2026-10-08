import Darwin
import Foundation

enum ProcessActions {
    /// System processes that must never be quit from the UI.
    private static let protectedNames: Set<String> = [
        "launchd", "loginwindow", "WindowServer", "kernel_task", "SystemUIServer",
        "Finder", "Dock", "UserEventAgent", "symptomsd", "runningboardd",
        "notifyd", "syspolicyd", "TCCD", "backboardd",
    ]

    /// Groups that are not application-level or that match known system daemons
    /// should not offer a quit action.
    static func isProtected(group: ProcessGroupStats) -> Bool {
        guard group.isApplication else { return true }
        if let pid = group.pid, pid == ProcessInfo.processInfo.processIdentifier { return true }
        return protectedNames.contains(group.name.lowercased())
    }

    /// Sends SIGTERM to the group's top process — the graceful, save-then-exit
    /// signal. Never SIGKILL. Errors (e.g. EPERM for protected/system processes)
    /// surface as a non-fatal alert message.
    static func quit(group: ProcessGroupStats, onError: (String) -> Void) {
        guard let pid = group.pid else { return }
        let result = kill(pid, SIGTERM)
        if result != 0 {
            onError("The system could not quit this process.")
        }
    }
}
