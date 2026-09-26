import Foundation

enum SearchEngine: String, CaseIterable, Identifiable {
    case duckDuckGo
    case brave
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duckDuckGo: return "DuckDuckGo"
        case .brave: return "Brave Search"
        case .google: return "Google"
        }
    }

    var searchURL: String {
        switch self {
        case .duckDuckGo: return "https://duckduckgo.com/"
        case .brave: return "https://search.brave.com/search"
        case .google: return "https://www.google.com/search"
        }
    }
}

@MainActor
final class BrowserPreferences: ObservableObject {
    private enum Key {
        static let searchEngine = "searchEngine"
        static let blocksTrackers = "blocksTrackers"
    }

    @Published var searchEngine: SearchEngine {
        didSet { UserDefaults.standard.set(searchEngine.rawValue, forKey: Key.searchEngine) }
    }

    @Published var blocksTrackers: Bool {
        didSet { UserDefaults.standard.set(blocksTrackers, forKey: Key.blocksTrackers) }
    }

    init() {
        let defaults = UserDefaults.standard
        searchEngine = SearchEngine(rawValue: defaults.string(forKey: Key.searchEngine) ?? "") ?? .duckDuckGo
        blocksTrackers = defaults.object(forKey: Key.blocksTrackers) as? Bool ?? true
    }
}
