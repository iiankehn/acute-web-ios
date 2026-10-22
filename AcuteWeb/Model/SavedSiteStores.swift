import Foundation

struct SavedSite: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let address: String
    let savedAt: Date
    var folder: String? = nil

    var url: URL? { WebAddress.url(address, allowMissingScheme: false) }

    func matchesSearch(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty || title.localizedCaseInsensitiveContains(term)
            || address.localizedCaseInsensitiveContains(term)
            || folder?.localizedCaseInsensitiveContains(term) == true
    }
}

@MainActor
final class BookmarkStore: ObservableObject {
    @Published private(set) var items: [SavedSite] = []
    private let defaultsKey = "bookmarks"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        items = load(defaultsKey, defaults: defaults)
    }

    var folders: [String] {
        Array(Set(items.compactMap(\.folder))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func contains(_ url: URL?) -> Bool {
        guard let url else { return false }
        return items.contains { $0.address == url.absoluteString }
    }

    func toggle(title: String, url: URL) {
        guard WebAddress.url(url.absoluteString, allowMissingScheme: false) != nil else { return }
        if let index = items.firstIndex(where: { $0.address == url.absoluteString }) {
            items.remove(at: index)
        } else {
            let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
            items.insert(SavedSite(id: UUID(), title: name.isEmpty ? (url.host ?? url.absoluteString) : name, address: url.absoluteString, savedAt: Date()), at: 0)
        }
        save(items, defaultsKey, defaults: defaults)
    }

    @discardableResult
    func update(_ item: SavedSite, title: String, address: String, folder: String? = nil) -> Bool {
        guard let url = Self.validatedURL(address), let index = items.firstIndex(where: { $0.id == item.id }) else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index] = SavedSite(id: item.id, title: trimmedTitle.isEmpty ? (url.host ?? url.absoluteString) : trimmedTitle,
                                address: url.absoluteString, savedAt: item.savedAt,
                                folder: trimmedFolder?.isEmpty == false ? trimmedFolder : nil)
        items.removeAll { $0.id != item.id && $0.address == url.absoluteString }
        save(items, defaultsKey, defaults: defaults)
        return true
    }

    static func validatedURL(_ address: String) -> URL? {
        WebAddress.url(address)
    }

    func remove(_ item: SavedSite) {
        items.removeAll { $0.id == item.id }
        save(items, defaultsKey, defaults: defaults)
    }

    /// Adds web bookmarks that are not already saved and returns how many were added.
    @discardableResult
    func importSites(_ sites: [SavedSite]) -> Int {
        var added = 0
        for site in sites where site.url != nil && !items.contains(where: { $0.address == site.address }) {
            items.append(site)
            added += 1
        }
        if added > 0 { save(items, defaultsKey, defaults: defaults) }
        return added
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [SavedSite] = []
    private let defaultsKey = "history"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        items = load(defaultsKey, defaults: defaults)
    }

    func record(title: String, url: URL) {
        guard WebAddress.url(url.absoluteString, allowMissingScheme: false) != nil else { return }
        items.removeAll { $0.address == url.absoluteString }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items.insert(SavedSite(id: UUID(), title: name.isEmpty ? (url.host ?? url.absoluteString) : name, address: url.absoluteString, savedAt: Date()), at: 0)
        items = Array(items.prefix(500))
        save(items, defaultsKey, defaults: defaults)
    }

    func remove(_ item: SavedSite) {
        items.removeAll { $0.id == item.id }
        save(items, defaultsKey, defaults: defaults)
    }

    func clear() {
        items.removeAll()
        defaults.removeObject(forKey: defaultsKey)
    }
}

/// Start-page favorites. The defaults are shown until the user changes the list.
@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var items: [SavedSite] = []
    private let defaultsKey = "startFavorites"
    private let defaults: UserDefaults

    static let defaultSites: [(title: String, address: String)] = [
        ("Wikipedia", "https://wikipedia.org"),
        ("GitHub", "https://github.com"),
        ("DuckDuckGo", "https://duckduckgo.com")
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: defaultsKey) == nil {
            items = Self.defaultSites.map {
                SavedSite(id: UUID(), title: $0.title, address: $0.address, savedAt: Date(timeIntervalSince1970: 0))
            }
        } else {
            items = load(defaultsKey, defaults: defaults)
        }
    }

    func contains(_ url: URL?) -> Bool {
        guard let url else { return false }
        return items.contains { $0.address == url.absoluteString }
    }

    func add(title: String, url: URL) {
        guard WebAddress.url(url.absoluteString, allowMissingScheme: false) != nil, !contains(url) else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(SavedSite(id: UUID(), title: name.isEmpty ? (url.host ?? url.absoluteString) : name,
                               address: url.absoluteString, savedAt: Date()))
        save(items, defaultsKey, defaults: defaults)
    }

    func remove(_ item: SavedSite) {
        items.removeAll { $0.id == item.id }
        save(items, defaultsKey, defaults: defaults)
    }

    func restoreDefaults() {
        defaults.removeObject(forKey: defaultsKey)
        items = Self.defaultSites.map {
            SavedSite(id: UUID(), title: $0.title, address: $0.address, savedAt: Date(timeIntervalSince1970: 0))
        }
    }
}

private func load(_ key: String, defaults: UserDefaults = .standard) -> [SavedSite] {
    guard let data = defaults.data(forKey: key) else { return [] }
    return ((try? JSONDecoder().decode([SavedSite].self, from: data)) ?? []).filter { $0.url != nil }
}

private func save(_ sites: [SavedSite], _ key: String, defaults: UserDefaults = .standard) {
    guard let data = try? JSONEncoder().encode(sites) else { return }
    defaults.set(data, forKey: key)
}
