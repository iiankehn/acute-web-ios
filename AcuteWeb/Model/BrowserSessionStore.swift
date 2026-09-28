import Foundation

struct RestorableBrowserTab: Codable, Equatable {
    let address: String
    let usesDesktopSite: Bool

    var url: URL? {
        guard let url = URL(string: address),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return nil }
        return url
    }
}

struct BrowserSession: Codable, Equatable {
    let tabs: [RestorableBrowserTab]
    let selectedIndex: Int
}

final class BrowserSessionStore {
    private let defaults: UserDefaults
    private let defaultsKey: String

    init(defaults: UserDefaults = .standard, defaultsKey: String = "browserSession") {
        self.defaults = defaults
        self.defaultsKey = defaultsKey
    }

    func load() -> BrowserSession? {
        guard let data = defaults.data(forKey: defaultsKey),
              let session = try? JSONDecoder().decode(BrowserSession.self, from: data),
              !session.tabs.isEmpty else { return nil }
        return session
    }

    func save(_ session: BrowserSession) {
        guard !session.tabs.isEmpty,
              let data = try? JSONEncoder().encode(session) else {
            clear()
            return
        }
        defaults.set(data, forKey: defaultsKey)
    }

    func clear() {
        defaults.removeObject(forKey: defaultsKey)
    }
}
