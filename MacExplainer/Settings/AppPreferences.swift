import Foundation
import Observation

@Observable
final class AppPreferences {
    static let supportedIntervals: [TimeInterval] = [1, 2, 5]

    var sampleInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(sampleInterval, forKey: Keys.sampleInterval)
        }
    }

    var historyWindow: HistoryWindow {
        didSet {
            UserDefaults.standard.set(historyWindow.rawValue, forKey: Keys.historyWindow)
        }
    }

    var showsMenuBarExtra: Bool {
        didSet {
            UserDefaults.standard.set(showsMenuBarExtra, forKey: Keys.showsMenuBarExtra)
        }
    }

    var startsAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(startsAtLogin, forKey: Keys.startsAtLogin)
        }
    }

    var menuBarMetrics: MenuBarMetricsStyle {
        didSet {
            UserDefaults.standard.set(menuBarMetrics.rawValue, forKey: Keys.menuBarMetrics)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        let storedInterval = defaults.double(forKey: Keys.sampleInterval)
        sampleInterval = AppPreferences.supportedIntervals.contains(storedInterval) ? storedInterval : 2
        let storedWindow = defaults.double(forKey: Keys.historyWindow)
        historyWindow = HistoryWindow(rawValue: storedWindow) ?? .thirtyMinutes
        if defaults.object(forKey: Keys.showsMenuBarExtra) != nil {
            showsMenuBarExtra = defaults.bool(forKey: Keys.showsMenuBarExtra)
        } else {
            showsMenuBarExtra = true
        }
        startsAtLogin = defaults.bool(forKey: Keys.startsAtLogin)
        menuBarMetrics = MenuBarMetricsStyle(rawValue: defaults.string(forKey: Keys.menuBarMetrics) ?? "") ?? .popupOnly
    }

    private enum Keys {
        static let sampleInterval = "preferences.sampleInterval"
        static let historyWindow = "preferences.historyWindow"
        static let showsMenuBarExtra = "preferences.showsMenuBarExtra"
        static let startsAtLogin = "preferences.startsAtLogin"
        static let menuBarMetrics = "preferences.menuBarMetrics"
    }
}

enum MenuBarMetricsStyle: String, Sendable {
    case popupOnly
    case inMenuBar
}
