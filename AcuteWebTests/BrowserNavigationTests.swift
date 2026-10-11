import XCTest
import SwiftUI
import WebKit
@testable import AcuteWeb

final class BrowserNavigationTests: XCTestCase {
    @MainActor
    private func makeBrowser() -> BrowserStore {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return BrowserStore(sessionStore: BrowserSessionStore(defaults: defaults))
    }

    @MainActor
    func testNewTabsHavePolicyDelegatesBeforeTheirFirstNavigation() {
        let browser = makeBrowser()
        for isPrivate in [false, true] {
            browser.newTab(isPrivate: isPrivate)
            let tab = browser.selectedTab!
            XCTAssertNotNil(tab.webView.navigationDelegate)
            XCTAssertNotNil(tab.webView.uiDelegate)
            XCTAssertEqual(tab.webView.configuration.websiteDataStore.isPersistent, !isPrivate)
        }
    }

    @MainActor
    func testFirstPageHonorsDisabledJavaScriptWithoutMountingBrowserView() {
        let browser = makeBrowser()
        let host = "acute-navigation-test.invalid"
        browser.sitePrivacy.update(host: host) { $0.allowsJavaScript = false }
        defer { browser.sitePrivacy.reset(host: host) }
        let tab = browser.selectedTab!
        tab.webView.loadHTMLString(
            "<html><head><title>Script blocked</title></head><body><script>document.title='Script ran';</script></body></html>",
            baseURL: URL(string: "https://\(host)/")
        )
        let finished = expectation(for: NSPredicate { _, _ in
            tab.webView.title != nil && !tab.webView.isLoading
        }, evaluatedWith: nil)
        wait(for: [finished], timeout: 15)
        XCTAssertEqual(tab.webView.title, "Script blocked")
    }

    @MainActor
    func testWindowOpenedFromPrivatePageCreatesANewPrivateTab() {
        let browser = makeBrowser()
        browser.newTab(isPrivate: true)
        let source = browser.selectedTab!
        source.webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        source.webView.loadHTMLString("<title>Private source</title>", baseURL: URL(string: "about:blank"))
        let loaded = expectation(for: NSPredicate { _, _ in source.webView.title == "Private source" }, evaluatedWith: nil)
        wait(for: [loaded], timeout: 15)
        let originalCount = browser.tabs.count
        source.webView.evaluateJavaScript("window.open('https://acute-link-test.invalid/');")
        let created = expectation(for: NSPredicate { _, _ in browser.tabs.count == originalCount + 1 }, evaluatedWith: nil)
        wait(for: [created], timeout: 10)
        XCTAssertTrue(browser.selectedTab!.isPrivate)
        XCTAssertFalse(browser.selectedTab!.webView.configuration.websiteDataStore.isPersistent)
        XCTAssertEqual(browser.selectedTab!.lastRequestedURL?.host, "acute-link-test.invalid")
        source.webView.stopLoading()
        browser.selectedTab?.webView.stopLoading()
    }

    @MainActor
    func testUnsupportedLinksDoNotCreateTabs() {
        let browser = makeBrowser()
        let originalCount = browser.tabs.count
        browser.openInNewTab(URL(string: "file:///private/file")!)
        browser.openInNewTab(URL(string: "javascript:alert(1)")!)
        XCTAssertEqual(browser.tabs.count, originalCount)
    }

    @MainActor
    func testCancelledNavigationDoesNotShowAnErrorButConnectionFailureDoes() {
        let browser = makeBrowser()
        let tab = browser.selectedTab!
        let coordinator = tab.navigationCoordinator!
        coordinator.webView(tab.webView, didFailProvisionalNavigation: nil,
                            withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled))
        XCTAssertNil(tab.navigationError)
        coordinator.webView(tab.webView, didFailProvisionalNavigation: nil,
                            withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
        XCTAssertNotNil(tab.navigationError)
        coordinator.webView(tab.webView, didStartProvisionalNavigation: nil)
        XCTAssertNil(tab.navigationError)
    }

    @MainActor
    func testSwitchingTabsMountsTheSelectedWebViewAndDetachesThePreviousOne() {
        let browser = makeBrowser()
        let first = browser.selectedTab!
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: BrowserRootView().environmentObject(browser))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let mounted = expectation(for: NSPredicate { _, _ in first.webView.superview != nil }, evaluatedWith: nil)
        wait(for: [mounted], timeout: 5)
        browser.newTab()
        let second = browser.selectedTab!
        let switched = expectation(for: NSPredicate { _, _ in
            second.webView.superview != nil && first.webView.superview == nil
        }, evaluatedWith: nil)
        wait(for: [switched], timeout: 5)
        browser.select(first)
        let returned = expectation(for: NSPredicate { _, _ in
            first.webView.superview != nil && second.webView.superview == nil
        }, evaluatedWith: nil)
        wait(for: [returned], timeout: 5)
    }
}
