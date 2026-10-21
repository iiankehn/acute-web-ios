import Foundation
import SwiftUI
import WebKit
import Combine

struct RecentSite: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: URL
}

enum TabCloseScope: String, CaseIterable, Identifiable {
    case regular, privateTabs, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .regular: return "Close Regular Tabs"
        case .privateTabs: return "Close Private Tabs"
        case .all: return "Close All Tabs"
        }
    }
    @MainActor func includes(_ tab: BrowserTab) -> Bool {
        switch self {
        case .regular: return !tab.isPrivate
        case .privateTabs: return tab.isPrivate
        case .all: return true
        }
    }
}

@MainActor
final class BrowserStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = [] {
        didSet { observeTabMetadata() }
    }
    @Published var selectedTabID: BrowserTab.ID?
    @Published var showsTabs = false
    @Published var showsSettings = false
    @Published var showsDownloads = false
    @Published var showsFindBar = false
    @Published var showsLibrary = false
    @Published var showsSitePrivacy = false
    @Published var addressDraft = ""
    @Published var addressInputError: String?
    @Published private(set) var addressFocusRequest = UUID()
    @Published private(set) var addressDismissRequest = UUID()
    /// True while the person is typing in the address or start-page search field.
    @Published var isEditingAddress = false
    @Published var findQuery = ""
    @Published private(set) var findStatus = ""
    @Published private(set) var recentlyClosed: [(url: URL?, isPrivate: Bool)] = []
    @Published private(set) var recentSites: [RecentSite] = []
    @Published private(set) var trackerProtectionUnavailable = false

    let services: BrowserServices
    let permissionBroker = PermissionBroker()
    let scriptDialogs = ScriptDialogBroker()
    private let contentBlocker = ContentBlocker()
    private let sessionStore: BrowserSessionStore
    private var findRequestID = UUID()
    private var tabMetadataSubscriptions: [AnyCancellable] = []

    var preferences: BrowserPreferences { services.preferences }
    var downloadCenter: DownloadCenter { services.downloadCenter }
    var bookmarks: BookmarkStore { services.bookmarks }
    var history: HistoryStore { services.history }
    var favorites: FavoritesStore { services.favorites }
    var sitePrivacy: SitePrivacyStore { services.sitePrivacy }
    var sessionKey: String { sessionStore.defaultsKey }

    private func observeTabMetadata() {
        // Search results must follow title/address changes, including background tabs.
        tabMetadataSubscriptions = tabs.map { tab in
            tab.$title.combineLatest(tab.$url)
                .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }
    private(set) var allowsWebsitePrompts = true

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedTabID }
    }

    init(sessionStore: BrowserSessionStore = BrowserSessionStore(), preferences: BrowserPreferences? = nil,
         downloadCenter: DownloadCenter? = nil, services: BrowserServices? = nil) {
        self.sessionStore = sessionStore
        self.services = services ?? BrowserServices(defaults: sessionStore.defaults, preferences: preferences,
                                                    downloadCenter: downloadCenter)
        self.services.register(self)
        contentBlocker.statusChanged = { [weak self] failed in self?.trackerProtectionUnavailable = failed }
        if !self.preferences.restoresTabs || !restoreSession() {
            newTab()
        }
    }

    private func makeTab(isPrivate: Bool) -> BrowserTab {
        BrowserTab(isPrivate: isPrivate, dataStore: isPrivate ? services.privateDataStore : .default())
    }

    func newTab(isPrivate: Bool = false) {
        dismissRequestsForSelectedTab()
        closeFindBar()
        let tab = makeTab(isPrivate: isPrivate)
        configureNavigation(for: tab)
        tabs.append(tab)
        selectedTabID = tab.id
        addressDraft = ""
        addressInputError = nil
        contentBlocker.apply(enabled: preferences.blocksTrackers, to: tab.webView)
        saveSession()
    }

    func updateSceneActivity(isActive: Bool) {
        allowsWebsitePrompts = isActive
        if !isActive {
            for tab in tabs {
                scriptDialogs.cancel(tabID: tab.id)
                permissionBroker.cancel(tabID: tab.id)
            }
        }
    }

    func canPresentDialogs(for tab: BrowserTab) -> Bool {
        allowsWebsitePrompts && selectedTabID == tab.id
    }

    private func dismissRequestsForSelectedTab() {
        guard let id = selectedTabID else { return }
        scriptDialogs.cancel(tabID: id)
        permissionBroker.cancel(tabID: id)
    }

    private func configureNavigation(for tab: BrowserTab) {
        let coordinator = WebView.Coordinator(tab: tab, browser: self)
        tab.navigationCoordinator = coordinator
        tab.webView.navigationDelegate = coordinator
        tab.webView.uiDelegate = coordinator
    }

    func select(_ tab: BrowserTab) {
        guard tabs.contains(where: { $0.id == tab.id }) else { return }
        if selectedTabID != tab.id { dismissRequestsForSelectedTab() }
        closeFindBar()
        selectedTab?.captureSnapshot()
        selectedTabID = tab.id
        addressInputError = nil
        tab.loadDeferredContentIfNeeded()
        refreshAddress()
        showsTabs = false
        saveSession()
    }

    func selectAdjacentTab(backwards: Bool = false) {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        let offset = backwards ? -1 : 1
        select(tabs[(index + offset + tabs.count) % tabs.count])
    }

    /// Command-1 through Command-8 choose a tab by position; Command-9 chooses the last tab.
    func selectTab(number: Int) {
        guard !tabs.isEmpty, number >= 1 else { return }
        if number >= 9 { select(tabs[tabs.count - 1]) }
        else if number <= tabs.count { select(tabs[number - 1]) }
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        scriptDialogs.cancel(tabID: tab.id)
        permissionBroker.cancel(tabID: tab.id)
        tab.webView.stopLoading()
        tab.captureSnapshot()
        if !tab.isPrivate {
            recentlyClosed.insert((tab.url ?? tab.lastRequestedURL, false), at: 0)
            recentlyClosed = Array(recentlyClosed.prefix(10))
        }
        tabs.remove(at: index)
        if tabs.isEmpty { newTab() }
        if selectedTabID == tab.id {
            closeFindBar()
            let next = tabs[min(index, tabs.count - 1)]
            selectedTabID = next.id
            next.loadDeferredContentIfNeeded()
            refreshAddress()
        }
        if tab.isPrivate { services.privateBrowsingMayHaveEnded() }
        saveSession()
    }

    func closeTabs(_ scope: TabCloseScope) {
        let closing = tabs.filter { scope.includes($0) }
        guard !closing.isEmpty else { return }
        let closedIDs = Set(closing.map(\.id))
        for tab in closing {
            scriptDialogs.cancel(tabID: tab.id)
            permissionBroker.cancel(tabID: tab.id)
            tab.webView.stopLoading()
            if !tab.isPrivate {
                recentlyClosed.insert((tab.url ?? tab.lastRequestedURL, false), at: 0)
            }
        }
        recentlyClosed = Array(recentlyClosed.prefix(10))
        tabs.removeAll { closedIDs.contains($0.id) }
        if tabs.isEmpty {
            newTab()
        } else if selectedTabID.map({ closedIDs.contains($0) }) == true {
            closeFindBar()
            selectedTabID = tabs[0].id
            tabs[0].loadDeferredContentIfNeeded()
            refreshAddress()
        }
        if closing.contains(where: \.isPrivate) { services.privateBrowsingMayHaveEnded() }
        saveSession()
    }

    func navigate() {
        closeFindBar()
        guard let tab = selectedTab, !addressDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let url = AddressResolver.resolve(addressDraft, searchEngine: preferences.searchEngine) else {
            addressInputError = "Enter a valid HTTP or HTTPS address, or search terms. Other address schemes cannot be entered here."
            return
        }
        addressInputError = nil
        tab.showFailure(nil)
        tab.awaitsRestoredLoad = false
        tab.lastRequestedURL = url
        tab.webView.load(URLRequest(url: url))
        addressDraft = url.absoluteString
        saveSession(selectedURLOverride: url)
    }

    func showStartPage() {
        guard let oldTab = selectedTab, let index = tabs.firstIndex(where: { $0.id == oldTab.id }) else { return }
        dismissRequestsForSelectedTab()
        closeFindBar()
        oldTab.webView.stopLoading()
        let tab = makeTab(isPrivate: oldTab.isPrivate)
        configureNavigation(for: tab)
        tabs[index] = tab
        selectedTabID = tab.id
        addressDraft = ""
        addressInputError = nil
        contentBlocker.apply(enabled: preferences.blocksTrackers, to: tab.webView)
        saveSession()
    }

    func retryNavigation() {
        guard let tab = selectedTab, let url = tab.lastRequestedURL else { return }
        tab.showFailure(nil)
        tab.awaitsRestoredLoad = false
        tab.reloadsWhenSelected = false
        addressInputError = nil
        addressDraft = url.absoluteString
        tab.webView.load(URLRequest(url: url))
    }

    /// Offered only after HTTPS failed in a way that suggests the site has no secure version.
    func retryOverHTTP() {
        guard let tab = selectedTab, let url = tab.lastRequestedURL,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https" else { return }
        components.scheme = "http"
        if components.port == 443 { components.port = nil }
        guard let insecure = components.url else { return }
        tab.lastRequestedURL = insecure
        retryNavigation()
        saveSession(selectedURLOverride: insecure)
    }

    func focusAddress() {
        closeFindBar()
        addressFocusRequest = UUID()
    }

    func endAddressEditing() {
        addressDismissRequest = UUID()
    }

    func refreshAddress() {
        addressDraft = (selectedTab?.url ?? selectedTab?.lastRequestedURL)?.absoluteString ?? ""
    }

    /// Follows page address changes without replacing what the person is typing.
    func syncAddressWithPage() {
        guard !isEditingAddress else { return }
        refreshAddress()
    }

    /// Local bookmark, favorite and history matches for the address field. Nothing is sent over the network.
    func addressSuggestions(for query: String, limit: Int = 6) -> [SavedSite] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, term != selectedTab?.url?.absoluteString else { return [] }
        var seen = Set<String>()
        let matches = (bookmarks.items + favorites.items + history.items).filter { site in
            site.matchesSearch(term) && seen.insert(site.address).inserted
        }
        return Array(matches.prefix(limit))
    }

    func duplicate(_ tab: BrowserTab) {
        newTab(isPrivate: tab.isPrivate)
        selectedTab?.setPageZoom(tab.pageZoom)
        selectedTab?.usesDesktopSite = tab.usesDesktopSite
        selectedTab?.webView.configuration.defaultWebpagePreferences.preferredContentMode = tab.usesDesktopSite ? .desktop : .mobile
        guard let url = tab.url ?? tab.lastRequestedURL else { saveSession(); return }
        selectedTab?.lastRequestedURL = url
        selectedTab?.webView.load(URLRequest(url: url))
        saveSession(selectedURLOverride: url)
    }

    func reopenLastClosedTab() {
        guard let closed = recentlyClosed.first else { return }
        recentlyClosed.removeFirst()
        newTab(isPrivate: closed.isPrivate)
        if let url = closed.url {
            selectedTab?.lastRequestedURL = url
            addressDraft = url.absoluteString
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

    /// A window opened by a website. WebKit loads the request into the returned web view.
    func openWebsiteWindow(configuration: WKWebViewConfiguration, request: URLRequest, isPrivate: Bool) -> WKWebView {
        dismissRequestsForSelectedTab()
        closeFindBar()
        let tab = BrowserTab(isPrivate: isPrivate, configuration: configuration)
        tab.wasOpenedByWebsite = true
        configureNavigation(for: tab)
        let webURL = request.url.flatMap { WebAddress.url($0.absoluteString, allowMissingScheme: false) }
        tab.lastRequestedURL = webURL
        tabs.append(tab)
        selectedTabID = tab.id
        addressDraft = webURL?.absoluteString ?? ""
        addressInputError = nil
        saveSession(selectedURLOverride: webURL)
        return tab.webView
    }

    func open(_ url: URL) {
        addressDraft = url.absoluteString
        navigate()
    }

    func prepareNavigation(_ webView: WKWebView, url: URL?, completion: @escaping () -> Void) {
        let isPrivate = tabs.first { $0.webView === webView }?.isPrivate ?? false
        let enabled = preferences.blocksTrackers && sitePrivacy.policy(for: url?.host, isPrivate: isPrivate).blocksTrackers
        contentBlocker.apply(enabled: enabled, to: webView, completion: completion)
    }

    func applyPrivacyPreferences() {
        for tab in tabs {
            applyPrivacyPreferences(to: tab)
        }
    }

    func applyPrivacyPreferences(to tab: BrowserTab) {
        let policy = sitePrivacy.policy(for: tab.url?.host, isPrivate: tab.isPrivate)
        contentBlocker.apply(enabled: preferences.blocksTrackers && policy.blocksTrackers, to: tab.webView)
    }

    func toggleBookmark() {
        guard let tab = selectedTab, !tab.isPrivate, let url = tab.url,
              WebAddress.url(url.absoluteString, allowMissingScheme: false) != nil else { return }
        bookmarks.toggle(title: tab.title, url: url)
        objectWillChange.send()
    }

    func toggleFavorite() {
        guard let tab = selectedTab, !tab.isPrivate, let url = tab.url,
              WebAddress.url(url.absoluteString, allowMissingScheme: false) != nil else { return }
        if let existing = favorites.items.first(where: { $0.address == url.absoluteString }) {
            favorites.remove(existing)
        } else {
            favorites.add(title: tab.title, url: url)
        }
        objectWillChange.send()
    }

    func confirmDownload(_ download: WKDownload, filename: String, completion: @escaping (Bool) -> Void) {
        guard let tab = tabs.first(where: { $0.webView === download.webView }), canPresentDialogs(for: tab) else {
            completion(false)
            return
        }
        let source = download.originalRequest?.url?.host ?? tab.url?.host ?? "This website"
        let warning = tab.isPrivate ? "\n\nDownloaded files stay on this device after private browsing ends." : ""
        scriptDialogs.request(tabID: tab.id, host: "Download File?",
                              message: "\(source) wants to download “\(filename)”.\(warning)", kind: .download) { answer in
            if case .accept = answer { completion(true) } else { completion(false) }
        }
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

    func clearRegularWebsiteData(completion: @escaping () -> Void) {
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
            Task { @MainActor in completion() }
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

    func setPageZoom(_ value: Double) {
        selectedTab?.setPageZoom(value)
        saveSession()
    }

    func saveSession() {
        saveSession(selectedURLOverride: nil)
    }

    /// Applies the Restore regular tabs setting; turning it off removes every window's saved tabs.
    func applySessionPreferences() {
        if !preferences.restoresTabs { services.clearSavedSessions() }
        saveSession()
    }

    /// Restored tabs keep their addresses but only the selected one loads, so launch stays fast and
    /// saved sites are not contacted until they are shown.
    @discardableResult
    private func restoreSession() -> Bool {
        guard let session = sessionStore.load() else { return false }

        let restored = session.tabs.enumerated().compactMap { entry -> (index: Int, tab: BrowserTab, address: String)? in
            let (index, saved) = entry
            guard saved.isStartPage || saved.url != nil else { return nil }
            let tab = makeTab(isPrivate: false)
            configureNavigation(for: tab)
            tab.usesDesktopSite = saved.usesDesktopSite
            tab.setPageZoom(saved.pageZoom)
            tab.webView.configuration.defaultWebpagePreferences.preferredContentMode = saved.usesDesktopSite ? .desktop : .mobile
            contentBlocker.apply(enabled: preferences.blocksTrackers, to: tab.webView)
            if let url = saved.url {
                tab.lastRequestedURL = url
                tab.awaitsRestoredLoad = true
                tab.title = url.host ?? url.absoluteString
            }
            return (index, tab, saved.address)
        }

        guard let selected = restored.first(where: { $0.index >= session.selectedIndex }) ?? restored.last else {
            sessionStore.clear()
            return false
        }

        tabs = restored.map(\.tab)
        selectedTabID = selected.tab.id
        selected.tab.loadDeferredContentIfNeeded()
        addressDraft = selected.address
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
            let currentURL = tab.url ?? tab.lastRequestedURL
            let url = tab.id == selectedTabID ? (selectedURLOverride ?? currentURL) : currentURL
            if let url, WebAddress.url(url.absoluteString, allowMissingScheme: false) == nil { continue }

            if tab.id == selectedTabID {
                selectedRestorableIndex = savedTabs.count
            }
            savedTabs.append(RestorableBrowserTab(address: url?.absoluteString ?? "",
                                                   usesDesktopSite: tab.usesDesktopSite, pageZoom: tab.pageZoom))
        }

        guard !savedTabs.isEmpty else {
            sessionStore.clear()
            return
        }

        sessionStore.save(BrowserSession(tabs: savedTabs, selectedIndex: selectedRestorableIndex))
    }
}
