import XCTest
import WebKit
@testable import AcuteWeb

final class AuditHardeningTests: XCTestCase {
    @MainActor
    private func makeBrowser(_ defaults: UserDefaults = UserDefaults(suiteName: UUID().uuidString)!) -> BrowserStore {
        BrowserStore(sessionStore: BrowserSessionStore(defaults: defaults), preferences: BrowserPreferences(defaults: defaults))
    }

    @MainActor
    func testPolicyInterruptionsDoNotReplaceTheCurrentPageWithAnError() {
        let browser = makeBrowser()
        let tab = browser.selectedTab!
        let coordinator = tab.navigationCoordinator!
        for code in [102, 204] {
            coordinator.webView(tab.webView, didFailProvisionalNavigation: nil,
                                withError: NSError(domain: "WebKitErrorDomain", code: code))
            XCTAssertNil(tab.navigationError)
        }
        coordinator.webView(tab.webView, didFailProvisionalNavigation: nil,
                            withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted))
        XCTAssertEqual(tab.navigationFailure?.isCertificateProblem, true)
        XCTAssertTrue(tab.navigationError?.contains("certificate") == true)
    }

    func testInsecureRetryIsOfferedOnlyForHTTPSConnectionFailures() {
        let https = URL(string: "https://example.com")!
        let refused = NavigationFailure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost))
        XCTAssertTrue(refused.offersInsecureRetry(for: https))
        XCTAssertFalse(refused.offersInsecureRetry(for: URL(string: "http://example.com")!))
        let certificate = NavigationFailure(NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateHasBadDate))
        XCTAssertFalse(certificate.offersInsecureRetry(for: https))
    }

    @MainActor
    func testRepeatedWebsiteDialogsCanBeBlockedUntilThePageChanges() {
        let broker = ScriptDialogBroker()
        let tab = UUID()
        var cancellations = 0
        let completion: (ScriptDialogAnswer) -> Void = { if case .cancel = $0 { cancellations += 1 } }
        broker.request(tabID: tab, host: "spam.example", message: "1", kind: .alert, completion: completion)
        XCTAssertEqual(broker.pendingRequest?.offersSuppression, false)
        broker.request(tabID: tab, host: "spam.example", message: "2", kind: .alert, completion: completion)
        broker.request(tabID: tab, host: "spam.example", message: "3", kind: .alert, completion: completion)
        broker.request(tabID: tab, host: "spam.example", message: "4", kind: .alert, completion: completion)
        XCTAssertEqual(cancellations, 1, "Dialogs beyond the per-tab limit are cancelled")
        broker.suppress(requestID: broker.pendingRequest!.id)
        XCTAssertEqual(cancellations, 4)
        XCTAssertTrue(broker.isSuppressed(tabID: tab))
        broker.request(tabID: tab, host: "spam.example", message: "5", kind: .confirm, completion: completion)
        XCTAssertEqual(cancellations, 5)
        XCTAssertNil(broker.pendingRequest)
        broker.pageChanged(tabID: tab)
        XCTAssertFalse(broker.isSuppressed(tabID: tab))
    }

    @MainActor
    func testSecondDialogOffersSuppression() async throws {
        let broker = ScriptDialogBroker()
        let tab = UUID()
        broker.request(tabID: tab, host: "one.example", message: "First", kind: .alert) { _ in }
        broker.request(tabID: tab, host: "one.example", message: "Second", kind: .alert) { _ in }
        broker.resolve(.accept(""))
        // The queue advances in a main-actor task; awaiting yields to it instead of spinning the run loop.
        for _ in 0..<30 where broker.pendingRequest == nil {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(broker.pendingRequest?.message, "Second")
        XCTAssertEqual(broker.pendingRequest?.offersSuppression, true)
    }

    @MainActor
    func testPrivateSiteSettingsAreNeverSavedAndEndWithPrivateBrowsing() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let browser = makeBrowser(defaults)
        browser.newTab(isPrivate: true)
        let privateTab = browser.selectedTab!
        browser.sitePrivacy.update(host: "secret.example", isPrivate: true) { $0.allowsJavaScript = false }
        XCTAssertFalse(browser.sitePrivacy.policy(for: "secret.example", isPrivate: true).allowsJavaScript)
        XCTAssertTrue(browser.sitePrivacy.policy(for: "secret.example").allowsJavaScript)
        XCTAssertNil(defaults.data(forKey: "sitePrivacyPolicies"))
        XCTAssertTrue(SitePrivacyStore(defaults: defaults).policies.isEmpty)
        browser.close(privateTab)
        XCTAssertTrue(browser.sitePrivacy.policy(for: "secret.example", isPrivate: true).allowsJavaScript)
    }

    @MainActor
    func testSiteSettingsCoverWWWAndMigrateLegacyCameraBlocking() throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = Data(#"{"www.example.com":{"blocksTrackers":false,"allowsJavaScript":true,"blocksMediaCapture":true}}"#.utf8)
        defaults.set(legacy, forKey: "sitePrivacyPolicies")
        let store = SitePrivacyStore(defaults: defaults)
        let policy = store.policy(for: "example.com")
        XCTAssertFalse(policy.blocksTrackers)
        XCTAssertEqual(policy.mediaCapture, .block)
        XCTAssertEqual(store.policy(for: "WWW.Example.com"), policy)
        store.update(host: "www.example.com") { $0.mediaCapture = .allow }
        XCTAssertEqual(SitePrivacyStore(defaults: defaults).policy(for: "example.com").mediaCapture, .allow)
        store.resetAll()
        XCTAssertTrue(SitePrivacyStore(defaults: defaults).policies.isEmpty)
    }

    @MainActor
    func testPrivateTabsShareOneSessionThatEndsWithTheLastPrivateTab() {
        let browser = makeBrowser()
        browser.newTab(isPrivate: true)
        let first = browser.selectedTab!
        browser.newTab(isPrivate: true)
        let second = browser.selectedTab!
        let store = first.webView.configuration.websiteDataStore
        XCTAssertFalse(store.isPersistent)
        XCTAssertTrue(second.webView.configuration.websiteDataStore === store)
        browser.close(first)
        browser.close(second)
        browser.newTab(isPrivate: true)
        XCTAssertFalse(browser.selectedTab!.webView.configuration.websiteDataStore === store)
    }

    @MainActor
    func testWebsiteWindowKeepsTheOpenerSessionAndCanCloseItself() {
        let browser = makeBrowser()
        browser.newTab(isPrivate: true)
        let opener = browser.selectedTab!
        let configuration = opener.webView.configuration
        let request = URLRequest(url: URL(string: "https://acute-popup.invalid/")!)
        let webView = browser.openWebsiteWindow(configuration: configuration, request: request, isPrivate: true)
        let popup = browser.selectedTab!
        XCTAssertTrue(popup.webView === webView)
        XCTAssertTrue(popup.isPrivate)
        XCTAssertTrue(popup.wasOpenedByWebsite)
        XCTAssertTrue(webView.configuration.websiteDataStore === opener.webView.configuration.websiteDataStore)
        XCTAssertEqual(popup.lastRequestedURL?.host, "acute-popup.invalid")
        popup.navigationCoordinator!.webViewDidClose(webView)
        XCTAssertFalse(browser.tabs.contains { $0.id == popup.id })
        opener.navigationCoordinator!.webViewDidClose(opener.webView)
        XCTAssertTrue(browser.tabs.contains { $0.id == opener.id }, "Tabs the person opened are not closed by websites")
    }

    @MainActor
    func testRestoredBackgroundTabsWaitUntilSelected() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = BrowserSessionStore(defaults: defaults)
        store.save(BrowserSession(tabs: [
            RestorableBrowserTab(address: "https://background.invalid/", usesDesktopSite: false),
            RestorableBrowserTab(address: "https://selected.invalid/", usesDesktopSite: false)
        ], selectedIndex: 1))
        let browser = BrowserStore(sessionStore: store, preferences: BrowserPreferences(defaults: defaults))
        let background = browser.tabs[0]
        XCTAssertTrue(background.awaitsRestoredLoad)
        XCTAssertEqual(background.title, "background.invalid")
        XCTAssertFalse(browser.tabs[1].awaitsRestoredLoad)
        browser.select(background)
        XCTAssertFalse(background.awaitsRestoredLoad)
        XCTAssertEqual(browser.addressDraft, "https://background.invalid/")
        browser.tabs.forEach { $0.webView.stopLoading() }
    }

    @MainActor
    func testBackgroundTabReloadsAfterItsWebsiteProcessEnds() {
        let browser = makeBrowser()
        let background = browser.selectedTab!
        background.lastRequestedURL = URL(string: "https://reclaimed.invalid/")!
        browser.newTab()
        background.navigationCoordinator!.webViewWebContentProcessDidTerminate(background.webView)
        XCTAssertTrue(background.reloadsWhenSelected)
        browser.select(background)
        XCTAssertFalse(background.reloadsWhenSelected)
        XCTAssertNil(background.navigationError)
        background.webView.stopLoading()
    }

    @MainActor
    func testAddressEditingIsNotOverwrittenByPageChanges() {
        let browser = makeBrowser()
        browser.selectedTab!.lastRequestedURL = URL(string: "https://page.invalid/")!
        browser.isEditingAddress = true
        browser.addressDraft = "what I am typing"
        browser.syncAddressWithPage()
        XCTAssertEqual(browser.addressDraft, "what I am typing")
        browser.isEditingAddress = false
        browser.syncAddressWithPage()
        XCTAssertEqual(browser.addressDraft, "https://page.invalid/")
    }

    @MainActor
    func testAddressSuggestionsUseOnlyLocalSavedSites() {
        let browser = makeBrowser()
        browser.bookmarks.toggle(title: "Swift Forums", url: URL(string: "https://forums.swift.org")!)
        browser.history.record(title: "Swift Package Index", url: URL(string: "https://swiftpackageindex.com")!)
        browser.history.record(title: "Swift Forums again", url: URL(string: "https://forums.swift.org")!)
        let suggestions = browser.addressSuggestions(for: "swift")
        XCTAssertEqual(suggestions.map(\.address), ["https://forums.swift.org", "https://swiftpackageindex.com"])
        XCTAssertTrue(browser.addressSuggestions(for: "  ").isEmpty)
    }

    @MainActor
    func testDownloadsNeedAVisibleTabInTheActiveWindow() {
        let browser = makeBrowser()
        var decisions: [Bool] = []
        let decided = expectation(description: "Download decisions")
        decided.expectedFulfillmentCount = 2
        let unrelated = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        unrelated.startDownload(using: URLRequest(url: URL(string: "https://download.invalid/one.txt")!)) { download in
            browser.confirmDownload(download, filename: "one.txt") { decisions.append($0); decided.fulfill() }
            download.cancel { _ in }
        }
        browser.updateSceneActivity(isActive: false)
        browser.selectedTab!.webView.startDownload(using: URLRequest(url: URL(string: "https://download.invalid/two.txt")!)) { download in
            browser.confirmDownload(download, filename: "two.txt") { decisions.append($0); decided.fulfill() }
            download.cancel { _ in }
        }
        wait(for: [decided], timeout: 30)
        XCTAssertEqual(decisions, [false, false])
        XCTAssertNil(browser.scriptDialogs.pendingRequest)
    }

    @MainActor
    func testFavoritesStartWithDefaultsAndCanBeEdited() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let favorites = FavoritesStore(defaults: defaults)
        XCTAssertEqual(favorites.items.map(\.title), FavoritesStore.defaultSites.map(\.title))
        favorites.remove(favorites.items[0])
        favorites.add(title: "Swift", url: URL(string: "https://swift.org")!)
        favorites.add(title: "Duplicate", url: URL(string: "https://swift.org")!)
        favorites.add(title: "Unsafe", url: URL(string: "javascript:alert(1)")!)
        XCTAssertEqual(FavoritesStore(defaults: defaults).items.map(\.title), ["GitHub", "DuckDuckGo", "Swift"])
        favorites.restoreDefaults()
        XCTAssertEqual(FavoritesStore(defaults: defaults).items.count, 3)
    }

    func testBookmarkFilesRoundTripFoldersAndSkipUnsafeLinks() {
        let sites = [
            SavedSite(id: UUID(), title: "Swift & Co <docs>", address: "https://swift.org/?a=1&b=2", savedAt: Date(timeIntervalSince1970: 1000)),
            SavedSite(id: UUID(), title: "Apple", address: "https://apple.com", savedAt: Date(timeIntervalSince1970: 2000), folder: "Work")
        ]
        let imported = BookmarkExchange.importHTML(BookmarkExchange.exportHTML(sites)
            + "<DT><A HREF=\"javascript:alert(1)\">Unsafe</A>")
        XCTAssertEqual(imported.map(\.title), ["Swift & Co <docs>", "Apple"])
        XCTAssertEqual(imported.map(\.address), ["https://swift.org/?a=1&b=2", "https://apple.com"])
        XCTAssertEqual(imported.map(\.folder), [nil, "Work"])
        XCTAssertEqual(imported[1].savedAt, Date(timeIntervalSince1970: 2000))
    }

    @MainActor
    func testImportingBookmarksSkipsDuplicates() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = BookmarkStore(defaults: defaults)
        store.toggle(title: "Existing", url: URL(string: "https://example.com")!)
        let added = store.importSites([
            SavedSite(id: UUID(), title: "Copy", address: "https://example.com", savedAt: Date()),
            SavedSite(id: UUID(), title: "New", address: "https://example.org", savedAt: Date(), folder: "Reading")
        ])
        XCTAssertEqual(added, 1)
        XCTAssertEqual(BookmarkStore(defaults: defaults).folders, ["Reading"])
    }

    @MainActor
    func testSessionKeysGiveEachWindowItsOwnSavedTabs() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let services = BrowserServices(defaults: defaults)
        let first = services.claimSessionKey(preferred: "")
        let second = services.claimSessionKey(preferred: "")
        XCTAssertEqual(first, BrowserSessionStore.primaryKey)
        XCTAssertNotEqual(second, first)
        XCTAssertNotEqual(services.claimSessionKey(preferred: first), first, "A key in use is not shared")
        let windowA = BrowserStore(sessionStore: BrowserSessionStore(defaults: defaults, defaultsKey: first), services: services)
        let windowB = BrowserStore(sessionStore: BrowserSessionStore(defaults: defaults, defaultsKey: second), services: services)
        windowA.selectedTab!.lastRequestedURL = URL(string: "https://a.invalid/")!
        windowA.saveSession()
        windowB.selectedTab!.lastRequestedURL = URL(string: "https://b.invalid/")!
        windowB.saveSession()
        XCTAssertEqual(BrowserSessionStore(defaults: defaults, defaultsKey: first).load()?.tabs.first?.address, "https://a.invalid/")
        XCTAssertEqual(BrowserSessionStore(defaults: defaults, defaultsKey: second).load()?.tabs.first?.address, "https://b.invalid/")
        services.clearSavedSessions()
        XCTAssertNil(BrowserSessionStore(defaults: defaults, defaultsKey: first).load())
        XCTAssertNil(BrowserSessionStore(defaults: defaults, defaultsKey: second).load())
    }

    @MainActor
    func testTrackerRulesBlockEmbeddedTrackerFramesButNotTopLevelVisits() throws {
        let data = Data(ContentBlocker.rules.utf8)
        let rules = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let frameRules = rules.compactMap { $0["trigger"] as? [String: Any] }
            .filter { ($0["resource-type"] as? [String]) == ["document"] }
        XCTAssertEqual(frameRules.count, ContentBlocker.trackerDomains.count)
        XCTAssertTrue(frameRules.allSatisfy { ($0["load-context"] as? [String]) == ["child-frame"] })
    }
}
