import Foundation

struct SavedSite: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let address: String
    let savedAt: Date

    var url: URL? { URL(string: address) }

    func matchesSearch(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty || title.localizedCaseInsensitiveContains(term)
            || address.localizedCaseInsensitiveContains(term)
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

    func contains(_ url: URL?) -> Bool {
        guard let url else { return false }
        return items.contains { $0.address == url.absoluteString }
    }

    func toggle(title: String, url: URL) {
        if let index = items.firstIndex(where: { $0.address == url.absoluteString }) {
            items.remove(at: index)
        } else {
            items.insert(SavedSite(id: UUID(), title: title, address: url.absoluteString, savedAt: Date()), at: 0)
        }
        save(items, defaultsKey, defaults: defaults)
    }

    @discardableResult
    func update(_ item: SavedSite, title: String, address: String) -> Bool {
        guard let url = Self.validatedURL(address), let index = items.firstIndex(where: { $0.id == item.id }) else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index] = SavedSite(id: item.id, title: trimmedTitle.isEmpty ? (url.host ?? url.absoluteString) : trimmedTitle,
                                address: url.absoluteString, savedAt: item.savedAt)
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
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [SavedSite] = []
    private let defaultsKey = "history"

    init() { items = load(defaultsKey) }

    func record(title: String, url: URL) {
        items.removeAll { $0.address == url.absoluteString }
        items.insert(SavedSite(id: UUID(), title: title, address: url.absoluteString, savedAt: Date()), at: 0)
        items = Array(items.prefix(500))
        save(items, defaultsKey)
    }

    func remove(_ item: SavedSite) {
        items.removeAll { $0.id == item.id }
        save(items, defaultsKey)
    }

    func clear() {
        items.removeAll()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

private func load(_ key: String, defaults: UserDefaults = .standard) -> [SavedSite] {
    guard let data = defaults.data(forKey: key) else { return [] }
    return (try? JSONDecoder().decode([SavedSite].self, from: data)) ?? []
}

private func save(_ sites: [SavedSite], _ key: String, defaults: UserDefaults = .standard) {
    guard let data = try? JSONEncoder().encode(sites) else { return }
    defaults.set(data, forKey: key)
}
