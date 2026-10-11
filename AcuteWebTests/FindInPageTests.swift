import XCTest
import UIKit
@testable import AcuteWeb

final class FindInPageTests: XCTestCase {
    @MainActor
    func testFindResultsAndResetAfterSwitchingTabs() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let browser = BrowserStore(sessionStore: BrowserSessionStore(defaults: defaults))
        let tab = browser.selectedTab!
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let controller = UIViewController()
        controller.view = tab.webView
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        tab.webView.loadHTMLString("<title>Find fixture</title><p>Acute browser search fixture</p>", baseURL: URL(string: "about:blank"))
        let loaded = expectation(for: NSPredicate { _, _ in
            tab.webView.title == "Find fixture" && !tab.webView.isLoading
        }, evaluatedWith: nil)
        wait(for: [loaded], timeout: 15)

        browser.showsFindBar = true
        browser.findQuery = "Acute"
        browser.findInPage()
        let found = expectation(for: NSPredicate { _, _ in browser.findStatus == "Match found" }, evaluatedWith: nil)
        wait(for: [found], timeout: 5)
        browser.findQuery = "does not exist"
        browser.findInPage()
        let absent = expectation(for: NSPredicate { _, _ in browser.findStatus == "No matches" }, evaluatedWith: nil)
        wait(for: [absent], timeout: 5)

        browser.findQuery = "  "
        browser.findInPage()
        XCTAssertEqual(browser.findStatus, "")
        browser.findQuery = "Acute"
        browser.findInPage()
        browser.newTab()
        XCTAssertFalse(browser.showsFindBar)
        XCTAssertEqual(browser.findQuery, "")
        XCTAssertEqual(browser.findStatus, "")
        // Let the old tab's callback finish, then confirm it cannot replace the cleared status.
        let flushed = expectation(description: "Old find callback flushed")
        tab.webView.evaluateJavaScript("document.title") { _, _ in flushed.fulfill() }
        wait(for: [flushed], timeout: 5)
        XCTAssertEqual(browser.findStatus, "")
    }
}
