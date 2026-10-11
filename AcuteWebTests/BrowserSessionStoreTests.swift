import XCTest
@testable import AcuteWeb

final class BrowserSessionStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: BrowserSessionStore!
    private let suiteName = "BrowserSessionStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = BrowserSessionStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    func testRoundTripsRestorableSession() {
        let session = BrowserSession(
            tabs: [
                RestorableBrowserTab(address: "https://example.com", usesDesktopSite: false),
                RestorableBrowserTab(address: "https://swift.org", usesDesktopSite: true)
            ],
            selectedIndex: 1
        )

        store.save(session)

        XCTAssertEqual(store.load(), session)
    }

    func testRejectsNonWebRestorationURL() {
        let saved = RestorableBrowserTab(address: "file:///private/document", usesDesktopSite: false)
        XCTAssertNil(saved.url)
        XCTAssertFalse(saved.isStartPage)
    }

    func testLegacySessionWithoutZoomStillLoadsAtActualSize() throws {
        let data = Data(#"{"tabs":[{"address":"https://example.com","usesDesktopSite":true}],"selectedIndex":0}"#.utf8)
        defaults.set(data, forKey: "browserSession")
        let session = try XCTUnwrap(store.load())
        XCTAssertEqual(session.tabs.first?.pageZoom, 1)
        XCTAssertEqual(session.tabs.first?.usesDesktopSite, true)
    }

    func testStartPagesAndZoomRoundTripWithSafeLimits() {
        let session = BrowserSession(tabs: [
            RestorableBrowserTab(address: "", usesDesktopSite: false),
            RestorableBrowserTab(address: "https://example.com", usesDesktopSite: true, pageZoom: 1.5)
        ], selectedIndex: 0)
        store.save(session)
        XCTAssertEqual(store.load(), session)
        XCTAssertTrue(store.load()!.tabs[0].isStartPage)
        XCTAssertEqual(RestorableBrowserTab(address: "", usesDesktopSite: false, pageZoom: 99).pageZoom, 2)
        XCTAssertEqual(RestorableBrowserTab(address: "", usesDesktopSite: false, pageZoom: .nan).pageZoom, 1)
    }

    @MainActor
    func testRecoveryPreservesStartPageSelectionAndExcludesPrivateTabs() throws {
        let preferences = BrowserPreferences(defaults: defaults)
        preferences.restoresTabs = true
        let browser = BrowserStore(sessionStore: store, preferences: preferences)
        browser.selectedTab!.lastRequestedURL = URL(string: "https://example.com")!
        browser.setPageZoom(1.5)
        browser.newTab(isPrivate: true)
        browser.selectedTab!.lastRequestedURL = URL(string: "https://private.example/secret")!
        browser.newTab()
        browser.saveSession()
        let saved = try XCTUnwrap(store.load())
        XCTAssertEqual(saved.tabs.count, 2)
        XCTAssertTrue(saved.tabs[1].isStartPage)
        XCTAssertEqual(saved.selectedIndex, 1)
        XCTAssertFalse(saved.tabs.contains { $0.address.contains("private.example") })

        let recovered = BrowserStore(sessionStore: store, preferences: preferences)
        XCTAssertEqual(recovered.tabs.count, 2)
        XCTAssertEqual(recovered.selectedTabID, recovered.tabs[1].id)
        XCTAssertNil(recovered.selectedTab?.url)
        XCTAssertEqual(recovered.addressDraft, "")
        XCTAssertEqual(recovered.tabs[0].pageZoom, 1.5)
        XCTAssertEqual(recovered.tabs[0].lastRequestedURL?.host, "example.com")
        recovered.tabs.forEach { $0.webView.stopLoading() }
    }

    @MainActor
    func testInvalidSavedEntriesDoNotShiftTheSelectedTab() {
        store.save(BrowserSession(tabs: [
            RestorableBrowserTab(address: "file:///private/document", usesDesktopSite: false),
            RestorableBrowserTab(address: "https://example.com", usesDesktopSite: false),
            RestorableBrowserTab(address: "", usesDesktopSite: false)
        ], selectedIndex: 1))
        let preferences = BrowserPreferences(defaults: defaults)
        preferences.restoresTabs = true
        let browser = BrowserStore(sessionStore: store, preferences: preferences)
        XCTAssertEqual(browser.tabs.count, 2)
        XCTAssertEqual(browser.selectedTabID, browser.tabs[0].id)
        XCTAssertEqual(browser.addressDraft, "https://example.com")
        browser.tabs.forEach { $0.webView.stopLoading() }
    }

    @MainActor
    func testDisablingRecoveryClearsPreviouslySavedTabs() {
        store.save(BrowserSession(tabs: [RestorableBrowserTab(address: "", usesDesktopSite: false)], selectedIndex: 0))
        let preferences = BrowserPreferences(defaults: defaults)
        preferences.restoresTabs = false
        let browser = BrowserStore(sessionStore: store, preferences: preferences)
        XCTAssertEqual(browser.tabs.count, 1)
        XCTAssertNil(store.load())
    }

    func testEmptySessionClearsPersistedState() {
        store.save(BrowserSession(
            tabs: [RestorableBrowserTab(address: "https://example.com", usesDesktopSite: false)],
            selectedIndex: 0
        ))

        store.save(BrowserSession(tabs: [], selectedIndex: 0))

        XCTAssertNil(store.load())
    }
}
