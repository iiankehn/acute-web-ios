import Foundation

struct RestorableBrowserTab: Codable, Equatable {
    let address: String
    let usesDesktopSite: Bool
    let pageZoom: Double

    var isStartPage: Bool { address.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case address, usesDesktopSite, pageZoom
    }

    init(address: String, usesDesktopSite: Bool, pageZoom: Double = 1) {
        self.address = address
        self.usesDesktopSite = usesDesktopSite
        self.pageZoom = pageZoom.isFinite ? min(max(pageZoom, 0.5), 2) : 1
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(address: try values.decode(String.self, forKey: .address),
                  usesDesktopSite: try values.decode(Bool.self, forKey: .usesDesktopSite),
                  pageZoom: try values.decodeIfPresent(Double.self, forKey: .pageZoom) ?? 1)
    }

    var url: URL? {
        WebAddress.url(address, allowMissingScheme: false)
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
