import Foundation
import WebKit

/// Saved browser state shared by every window. Each window keeps its own tabs in a `BrowserStore`.
@MainActor
final class BrowserServices {
    let preferences: BrowserPreferences
    let downloadCenter: DownloadCenter
    let bookmarks: BookmarkStore
    let history: HistoryStore
    let favorites: FavoritesStore
    let sitePrivacy: SitePrivacyStore
    let defaults: UserDefaults
    private var stores: [WeakStore] = []
    private var sharedPrivateDataStore: WKWebsiteDataStore?

    /// Private tabs share one non-persistent store, so sign-ins carry across private tabs until all are closed.
    var privateDataStore: WKWebsiteDataStore {
        if let sharedPrivateDataStore { return sharedPrivateDataStore }
        let store = WKWebsiteDataStore.nonPersistent()
        sharedPrivateDataStore = store
        return store
    }

    private struct WeakStore {
        weak var store: BrowserStore?
    }

    init(defaults: UserDefaults = .standard, preferences: BrowserPreferences? = nil, downloadCenter: DownloadCenter? = nil) {
        self.defaults = defaults
        self.preferences = preferences ?? BrowserPreferences(defaults: defaults)
        self.downloadCenter = downloadCenter ?? DownloadCenter()
        bookmarks = BookmarkStore(defaults: defaults)
        history = HistoryStore(defaults: defaults)
        favorites = FavoritesStore(defaults: defaults)
        sitePrivacy = SitePrivacyStore(defaults: defaults)
        self.downloadCenter.confirmDownload = { [weak self] download, filename, completion in
            // Downloads that no window can account for are not saved silently.
            guard let self, let owner = self.store(owning: download.webView) else { completion(false); return }
            owner.confirmDownload(download, filename: filename, completion: completion)
        }
    }

    func register(_ store: BrowserStore) {
        stores.removeAll { $0.store == nil }
        stores.append(WeakStore(store: store))
    }

    var activeStores: [BrowserStore] {
        stores.compactMap(\.store)
    }

    func store(owning webView: WKWebView?) -> BrowserStore? {
        guard let webView else { return nil }
        return activeStores.first { store in store.tabs.contains { $0.webView === webView } }
    }

    /// Private website data and site choices end only when no window still has a private tab.
    func privateBrowsingMayHaveEnded() {
        guard !activeStores.contains(where: { $0.tabs.contains(where: \.isPrivate) }) else { return }
        sitePrivacy.endPrivateBrowsing()
        sharedPrivateDataStore = nil
    }

    private var claimedSessionKeys: Set<String> = []

    /// Returns a window's restored session key, or a new one. The first window uses the original key.
    func claimSessionKey(preferred: String) -> String {
        if !preferred.isEmpty, !claimedSessionKeys.contains(preferred) {
            claimedSessionKeys.insert(preferred)
            return preferred
        }
        let primary = BrowserSessionStore.primaryKey
        let key = claimedSessionKeys.contains(primary) ? "\(primary).\(UUID().uuidString)" : primary
        claimedSessionKeys.insert(key)
        return key
    }

    /// Removes the saved tabs of every window, including windows that were closed.
    func clearSavedSessions() {
        let prefix = BrowserSessionStore.primaryKey
        for key in defaults.dictionaryRepresentation().keys where key == prefix || key.hasPrefix(prefix + ".") {
            defaults.removeObject(forKey: key)
        }
    }
}
