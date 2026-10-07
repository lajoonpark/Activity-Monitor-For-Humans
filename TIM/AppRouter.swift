import Foundation
import Observation

enum AppTab: String, Sendable {
    case overview, apps, energy, history, advanced, wiki, settings
}

/// Where a "What is this?" click wants the wiki to land. Identified so that
/// clicking the same process twice still re-focuses the wiki.
struct WikiRequest: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String?
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .overview
    var wikiRequest: WikiRequest?

    func openWiki(forName name: String, bundleIdentifier: String? = nil) {
        wikiRequest = WikiRequest(name: name, bundleIdentifier: bundleIdentifier)
        selectedTab = .wiki
    }
}
