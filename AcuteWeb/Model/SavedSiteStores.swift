import Foundation

struct SavedSite: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let address: String
    let savedAt: Date

    var url: URL? { URL(string: address) }
}

@MainActor
final class BookmarkStore: ObservableObject {
    @Published private(set) var items: [SavedSite] = []
    private let defaultsKey = "bookmarks"

    init() { items = load(defaultsKey) }

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
        save(items, defaultsKey)
    }

    func remove(_ item: SavedSite) {
        items.removeAll { $0.id == item.id }
        save(items, defaultsKey)
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

private func load(_ key: String) -> [SavedSite] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
    return (try? JSONDecoder().decode([SavedSite].self, from: data)) ?? []
}

private func save(_ sites: [SavedSite], _ key: String) {
    guard let data = try? JSONEncoder().encode(sites) else { return }
    UserDefaults.standard.set(data, forKey: key)
}
