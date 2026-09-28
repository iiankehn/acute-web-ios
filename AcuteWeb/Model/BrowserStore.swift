import Foundation
import SwiftUI
import WebKit

struct RecentSite: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: URL
}

@MainActor
final class BrowserStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var selectedTabID: BrowserTab.ID?
    @Published var showsTabs = false
    @Published var showsSettings = false
    @Published var showsDownloads = false
    @Published var showsFindBar = false
    @Published var showsLibrary = false
    @Published var showsSitePrivacy = false
    @Published var addressDraft = ""
    @Published var findQuery = ""
    @Published private(set) var findStatus = ""
    @Published private(set) var recentlyClosed: [(url: URL?, isPrivate: Bool)] = []
    @Published private(set) var recentSites: [RecentSite] = []

    let preferences = BrowserPreferences()
    let downloadCenter = DownloadCenter()
    let permissionBroker = PermissionBroker()
    let bookmarks = BookmarkStore()
    let history = HistoryStore()
    let sitePrivacy = SitePrivacyStore()
    private let contentBlocker = ContentBlocker()
    private let sessionStore: BrowserSessionStore

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedTabID }
    }

    init(sessionStore: BrowserSessionStore = BrowserSessionStore()) {
        self.sessionStore = sessionStore
        if !preferences.restoresTabs || !restoreSession() {
            newTab()
        }
    }

    func newTab(isPrivate: Bool = false) {
        let tab = BrowserTab(isPrivate: isPrivate)
        tabs.append(tab)
        selectedTabID = tab.id
        addressDraft = ""
        contentBlocker.apply(enabled: preferences.blocksTrackers, to: tab.webView)
    }

    func select(_ tab: BrowserTab) {
        selectedTab?.captureSnapshot()
        selectedTabID = tab.id
        addressDraft = tab.url?.absoluteString ?? ""
        showsTabs = false
        saveSession()
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.captureSnapshot()
        recentlyClosed.insert((tab.url, tab.isPrivate), at: 0)
        recentlyClosed = Array(recentlyClosed.prefix(10))
        tabs.remove(at: index)
        if tabs.isEmpty { newTab() }
        if selectedTabID == tab.id {
            selectedTabID = tabs[min(index, tabs.count - 1)].id
        }
        saveSession()
    }

    func navigate() {
        guard let tab = selectedTab,
              let url = AddressResolver.resolve(addressDraft, searchEngine: preferences.searchEngine) else { return }
        tab.webView.load(URLRequest(url: url))
        addressDraft = url.absoluteString
        saveSession(selectedURLOverride: url)
    }

    func refreshAddress() {
        addressDraft = selectedTab?.url?.absoluteString ?? ""
    }

    func duplicate(_ tab: BrowserTab) {
        newTab(isPrivate: tab.isPrivate)
        guard let url = tab.url else { return }
        selectedTab?.webView.load(URLRequest(url: url))
        saveSession(selectedURLOverride: url)
    }

    func reopenLastClosedTab() {
        guard let closed = recentlyClosed.first else { return }
        recentlyClosed.removeFirst()
        newTab(isPrivate: closed.isPrivate)
        if let url = closed.url {
            selectedTab?.webView.load(URLRequest(url: url))
            saveSession(selectedURLOverride: url)
        }
    }

    func moveTabs(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        saveSession()
    }

    func recordCurrentVisit() {
        guard let tab = selectedTab, !tab.isPrivate, let url = tab.url,
              let scheme = url.scheme, ["http", "https"].contains(scheme) else { return }
        recentSites.removeAll { $0.url.host == url.host }
        recentSites.insert(RecentSite(title: tab.title, url: url), at: 0)
        recentSites = Array(recentSites.prefix(6))
        if preferences.savesHistory {
            history.record(title: tab.title, url: url)
        }
        applyPrivacyPreferences(to: tab)
        saveSession()
    }

    func open(_ url: URL) {
        addressDraft = url.absoluteString
        navigate()
    }

    func applyPrivacyPreferences() {
        for tab in tabs {
            applyPrivacyPreferences(to: tab)
        }
    }

    func applyPrivacyPreferences(to tab: BrowserTab) {
        let policy = sitePrivacy.policy(for: tab.url?.host)
        contentBlocker.apply(enabled: preferences.blocksTrackers && policy.blocksTrackers, to: tab.webView)
    }

    func toggleBookmark() {
        guard let tab = selectedTab, !tab.isPrivate, let url = tab.url else { return }
        bookmarks.toggle(title: tab.title, url: url)
        objectWillChange.send()
    }

    func clearSiteData(host: String, completion: @escaping () -> Void) {
        guard let tab = selectedTab else { completion(); return }
        let store = tab.webView.configuration.websiteDataStore
        store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let matching = records.filter { $0.displayName == host || $0.displayName.hasSuffix(".\(host)") }
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: matching) {
                Task { @MainActor in completion() }
            }
        }
    }

    func findInPage(backwards: Bool = false) {
        guard let webView = selectedTab?.webView else { return }
        let query = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            findStatus = ""
            return
        }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.wraps = true
        webView.find(query, configuration: configuration) { [weak self] result in
            self?.findStatus = result.matchFound ? "Match found" : "No matches"
        }
    }

    func closeFindBar() {
        showsFindBar = false
        findQuery = ""
        findStatus = ""
    }

    func toggleDesktopSite() {
        selectedTab?.toggleDesktopSite()
        saveSession()
    }

    func saveSession() {
        saveSession(selectedURLOverride: nil)
    }

    @discardableResult
    private func restoreSession() -> Bool {
        guard let session = sessionStore.load() else { return false }

        let validSavedTabs = session.tabs.filter { $0.url != nil }
        let restoredTabs = validSavedTabs.compactMap { saved -> BrowserTab? in
            guard let url = saved.url else { return nil }
            let tab = BrowserTab()
            tab.usesDesktopSite = saved.usesDesktopSite
            tab.webView.configuration.defaultWebpagePreferences.preferredContentMode = saved.usesDesktopSite ? .desktop : .mobile
            contentBlocker.apply(enabled: preferences.blocksTrackers, to: tab.webView)
            tab.webView.load(URLRequest(url: url))
            return tab
        }

        guard !restoredTabs.isEmpty else {
            sessionStore.clear()
            return false
        }

        tabs = restoredTabs
        let selectedIndex = min(max(session.selectedIndex, 0), restoredTabs.count - 1)
        selectedTabID = restoredTabs[selectedIndex].id
        addressDraft = validSavedTabs[selectedIndex].address
        return true
    }

    private func saveSession(selectedURLOverride: URL?) {
        guard preferences.restoresTabs else {
            sessionStore.clear()
            return
        }

        var selectedRestorableIndex = 0
        var savedTabs: [RestorableBrowserTab] = []

        for tab in tabs where !tab.isPrivate {
            let url = tab.id == selectedTabID ? (selectedURLOverride ?? tab.url) : tab.url
            guard let url,
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else { continue }

            if tab.id == selectedTabID {
                selectedRestorableIndex = savedTabs.count
            }
            savedTabs.append(RestorableBrowserTab(address: url.absoluteString,
                                                   usesDesktopSite: tab.usesDesktopSite))
        }

        guard !savedTabs.isEmpty else {
            sessionStore.clear()
            return
        }

        sessionStore.save(BrowserSession(tabs: savedTabs, selectedIndex: selectedRestorableIndex))
    }
}
