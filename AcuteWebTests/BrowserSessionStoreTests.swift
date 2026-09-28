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
