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
    @Published private(set) var addressFocusRequest = UUID()
    @Published var findQuery = ""
    @Published private(set) var findStatus = ""
    @Published private(set) var recentlyClosed: [(url: URL?, isPrivate: Bool)] = []
    @Published private(set) var recentSites: [RecentSite] = []

    let preferences = BrowserPreferences()
    let downloadCenter = DownloadCenter()
    let permissionBroker = PermissionBroker()
    let scriptDialogs = ScriptDialogBroker()
    let bookmarks = BookmarkStore()
    let history = HistoryStore()
    let sitePrivacy = SitePrivacyStore()
    private let contentBlocker = ContentBlocker()
    private let sessionStore: BrowserSessionStore
    private var findRequestID = UUID()

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
        closeFindBar()
        let tab = BrowserTab(isPrivate: isPrivate)
        configureNavigation(for: tab)
        tabs.append(tab)
        selectedTabID = tab.id
        addressDraft = ""
        contentBlocker.apply(enabled: preferences.blocksTrackers, to: tab.webView)
    }

    private func configureNavigation(for tab: BrowserTab) {
        let coordinator = WebView.Coordinator(
            tab: tab, downloadCenter: downloadCenter,
            permissionBroker: permissionBroker, sitePrivacy: sitePrivacy,
            openLink: { [weak self] request, isPrivate in self?.openInNewTab(request, isPrivate: isPrivate) },
            scriptDialogs: scriptDialogs,
            prepareNavigation: { [weak self] webView, url, completion in
                guard let self else { completion(); return }
                let enabled = self.preferences.blocksTrackers && self.sitePrivacy.policy(for: url?.host).blocksTrackers
                self.contentBlocker.apply(enabled: enabled, to: webView, completion: completion)
            }
        )
        tab.navigationCoordinator = coordinator
        tab.webView.navigationDelegate = coordinator
        tab.webView.uiDelegate = coordinator
    }

    func select(_ tab: BrowserTab) {
        closeFindBar()
        selectedTab?.captureSnapshot()
        selectedTabID = tab.id
        addressDraft = tab.url?.absoluteString ?? ""
        showsTabs = false
        saveSession()
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        scriptDialogs.cancel(tabID: tab.id)
        tab.captureSnapshot()
        recentlyClosed.insert((tab.url, tab.isPrivate), at: 0)
        recentlyClosed = Array(recentlyClosed.prefix(10))
        tabs.remove(at: index)
        if tabs.isEmpty { newTab() }
        if selectedTabID == tab.id {
            closeFindBar()
            selectedTabID = tabs[min(index, tabs.count - 1)].id
            refreshAddress()
        }
        saveSession()
    }

    func navigate() {
        closeFindBar()
        guard let tab = selectedTab,
              let url = AddressResolver.resolve(addressDraft, searchEngine: preferences.searchEngine) else { return }
        tab.navigationError = nil
        tab.lastRequestedURL = url
        tab.webView.load(URLRequest(url: url))
        addressDraft = url.absoluteString
        saveSession(selectedURLOverride: url)
    }

    func retryNavigation() {
        guard let tab = selectedTab, let url = tab.lastRequestedURL else { return }
        tab.navigationError = nil
        addressDraft = url.absoluteString
        tab.webView.load(URLRequest(url: url))
    }

    func focusAddress() {
        closeFindBar()
        addressFocusRequest = UUID()
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

    func openInNewTab(_ url: URL, isPrivate: Bool = false) {
        openInNewTab(URLRequest(url: url), isPrivate: isPrivate)
    }

    func openInNewTab(_ request: URLRequest, isPrivate: Bool = false) {
        guard let url = request.url, let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return }
        newTab(isPrivate: isPrivate)
        selectedTab?.lastRequestedURL = url
        addressDraft = url.absoluteString
        selectedTab?.webView.load(request)
        saveSession(selectedURLOverride: url)
    }

    func open(_ url: URL) {
        addressDraft = url.absoluteString
        navigate()
    }

    func prepareNavigation(_ webView: WKWebView, url: URL?, completion: @escaping () -> Void) {
        let enabled = preferences.blocksTrackers && sitePrivacy.policy(for: url?.host).blocksTrackers
        contentBlocker.apply(enabled: enabled, to: webView, completion: completion)
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
            let matching = records.filter { SiteDataScope.matches(recordName: $0.displayName, host: host) }
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: matching) {
                Task { @MainActor in completion() }
            }
        }
    }

    func findInPage(backwards: Bool = false) {
        findRequestID = UUID()
        let requestID = findRequestID
        guard let tab = selectedTab else { return }
        let tabID = tab.id
        let webView = tab.webView
        let query = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            findStatus = ""
            return
        }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.wraps = true
        webView.find(query, configuration: configuration) { [weak self] result in
            guard let self, self.findRequestID == requestID, self.selectedTabID == tabID,
                  self.showsFindBar else { return }
            self.findStatus = result.matchFound ? "Match found" : "No matches"
        }
    }

    func closeFindBar() {
        findRequestID = UUID()
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
            configureNavigation(for: tab)
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
