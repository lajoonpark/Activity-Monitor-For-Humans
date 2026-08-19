import Foundation
import ServiceManagement

enum LoginItemService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return "Will not open at login."
        case .enabled:
            return "Opens when you log in."
        case .requiresApproval:
            return "Needs approval in System Settings."
        case .notFound:
            return "The app needs to be in Applications to start at login."
        @unknown default:
            return "Unknown status."
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
