import SwiftUI

enum Formatters {
    static func bytes(_ value: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var scaled = Double(value)
        var index = 0
        while scaled >= 1024, index < units.count - 1 {
            scaled /= 1024
            index += 1
        }
        if index == 0 {
            return "\(Int(scaled)) B"
        }
        return String(format: "%.1f %@", scaled, units[index])
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }

    static func rate(_ bytesPerSecond: UInt64) -> String {
        bytes(bytesPerSecond) + "/s"
    }

    /// Honest watts estimate: energy delta (nanojoules) divided by the sample
    /// interval in seconds. Never an "Energy Impact" number.
    static func watts(_ deltaNanojoules: UInt64?, interval: TimeInterval) -> String {
        guard let deltaNanojoules, interval > 0 else { return "—" }
        let joules = Double(deltaNanojoules) / 1_000_000_000
        let watts = joules / interval
        if watts == 0 { return "0 W" }
        return "about \(String(format: "%.1f", watts)) W"
    }
}

extension HealthLevel {
    var tintColor: Color {
        switch self {
        case .normal: return .green
        case .moderateLoad: return .yellow
        case .highLoad: return .orange
        case .potentialProblem: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .moderateLoad: return "exclamationmark.circle.fill"
        case .highLoad: return "exclamationmark.triangle.fill"
        case .potentialProblem: return "exclamationmark.triangle.fill"
        }
    }
}
