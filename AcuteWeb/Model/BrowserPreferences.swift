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
        static let savesHistory = "savesHistory"
        static let restoresTabs = "restoresTabs"
        static let showsStartBookmarks = "showsStartBookmarks"
        static let showsStartFavorites = "showsStartFavorites"
        static let showsStartRecentSites = "showsStartRecentSites"
    }

    private let defaults: UserDefaults

    @Published var searchEngine: SearchEngine {
        didSet { defaults.set(searchEngine.rawValue, forKey: Key.searchEngine) }
    }

    @Published var blocksTrackers: Bool {
        didSet { defaults.set(blocksTrackers, forKey: Key.blocksTrackers) }
    }

    @Published var savesHistory: Bool {
        didSet { defaults.set(savesHistory, forKey: Key.savesHistory) }
    }

    @Published var restoresTabs: Bool {
        didSet { defaults.set(restoresTabs, forKey: Key.restoresTabs) }
    }

    @Published var showsStartBookmarks: Bool {
        didSet { defaults.set(showsStartBookmarks, forKey: Key.showsStartBookmarks) }
    }

    @Published var showsStartFavorites: Bool {
        didSet { defaults.set(showsStartFavorites, forKey: Key.showsStartFavorites) }
    }

    @Published var showsStartRecentSites: Bool {
        didSet { defaults.set(showsStartRecentSites, forKey: Key.showsStartRecentSites) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func bool(_ key: String, fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        searchEngine = SearchEngine(rawValue: defaults.string(forKey: Key.searchEngine) ?? "") ?? .duckDuckGo
        blocksTrackers = bool(Key.blocksTrackers, fallback: true)
        savesHistory = bool(Key.savesHistory, fallback: false)
        restoresTabs = bool(Key.restoresTabs, fallback: true)
        showsStartBookmarks = bool(Key.showsStartBookmarks, fallback: true)
        showsStartFavorites = bool(Key.showsStartFavorites, fallback: true)
        showsStartRecentSites = bool(Key.showsStartRecentSites, fallback: true)
    }
}
