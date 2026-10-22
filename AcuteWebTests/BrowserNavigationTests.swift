import XCTest
import SwiftUI
import WebKit
@testable import AcuteWeb

final class BrowserNavigationTests: XCTestCase {
    @MainActor
    func testFailedAddressSurvivesTabSwitchAndClosedTabRecovery() {
        let browser = makeBrowser()
        let tab = browser.selectedTab!
        let url = URL(string: "https://acute-failed-address.invalid/path")!
        tab.lastRequestedURL = url
        tab.navigationError = "Offline"
        browser.newTab()
        browser.select(tab)
        XCTAssertEqual(browser.addressDraft, url.absoluteString)
        browser.close(tab)
        XCTAssertEqual(browser.recentlyClosed.first?.url, url)
        browser.reopenLastClosedTab()
        XCTAssertEqual(browser.selectedTab?.lastRequestedURL, url)
        XCTAssertEqual(browser.addressDraft, url.absoluteString)
        browser.selectedTab?.webView.stopLoading()
        let selected = browser.selectedTabID
        browser.select(tab)
        XCTAssertEqual(browser.selectedTabID, selected)
    }

    @MainActor
    func testWebKitDownloadCompletesAndIsRecoveredFromDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let center = DownloadCenter(directory: directory)
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let browser = BrowserStore(sessionStore: BrowserSessionStore(defaults: defaults),
                                   preferences: BrowserPreferences(defaults: defaults), downloadCenter: center)
        let tab = browser.selectedTab!
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let controller = UIViewController()
        controller.view = tab.webView
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            defaults.removePersistentDomain(forName: suite)
            center.items.filter { $0.state == .downloading }.forEach { center.cancel($0) }
            tab.webView.stopLoading()
            window.isHidden = true
            window.rootViewController = nil
            try? FileManager.default.removeItem(at: directory)
        }
        tab.webView.loadHTMLString("<title>Download fixture</title><body>Local download</body>", baseURL: URL(string: "about:blank"))
        let loaded = expectation(for: NSPredicate { _, _ in tab.webView.title == "Download fixture" && !tab.webView.isLoading }, evaluatedWith: nil)
        wait(for: [loaded], timeout: 20)
        tab.webView.evaluateJavaScript("const link=document.createElement('a'); link.href=URL.createObjectURL(new Blob(['Acute download fixture'],{type:'text/plain'})); link.download='acute-fixture.txt'; document.body.appendChild(link); link.click();")
        let asked = expectation(for: NSPredicate { _, _ in browser.scriptDialogs.pendingRequest?.kind == .download }, evaluatedWith: nil)
        wait(for: [asked], timeout: 25)
        XCTAssertTrue(center.items.isEmpty, "Nothing is saved before the person approves the download")
        browser.scriptDialogs.resolve(.accept(""))
        let completed = expectation(for: NSPredicate { _, _ in
            center.items.first.map { $0.state != .downloading } == true
        }, evaluatedWith: nil)
        wait(for: [completed], timeout: 25)
        let item = try XCTUnwrap(center.items.first)
        XCTAssertEqual(item.state, .finished, item.failureReason ?? "Download did not finish")
        let destination = try XCTUnwrap(item.destination)
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "Acute download fixture")
        let stagingFiles = try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent(".in-progress").path)
        XCTAssertTrue(stagingFiles.isEmpty, "Completed downloads must not leave partial files")
        XCTAssertEqual(DownloadCenter(directory: directory).items.first?.filename, "acute-fixture.txt")
    }

    @MainActor
    func testBulkClosingPreservesUntargetedTabAndNeverRetainsPrivateAddresses() {
        let browser = makeBrowser()
        browser.newTab()
        browser.newTab(isPrivate: true)
        let privateTab = browser.selectedTab!
        privateTab.lastRequestedURL = URL(string: "https://private.example/secret")!
        var denied = false
        browser.permissionBroker.request(tabID: privateTab.id, host: "private.example", kind: .camera) { denied = $0 == .deny }
        browser.closeTabs(.regular)
        XCTAssertEqual(browser.tabs.count, 1)
        XCTAssertEqual(browser.selectedTabID, privateTab.id)
        XCTAssertFalse(denied)
        XCTAssertNotNil(browser.permissionBroker.pendingRequest)
        browser.closeTabs(.privateTabs)
        XCTAssertTrue(denied)
        XCTAssertEqual(browser.tabs.count, 1)
        XCTAssertFalse(browser.selectedTab!.isPrivate)
        XCTAssertFalse(browser.recentlyClosed.contains { $0.url?.host == "private.example" })
        browser.newTab()
        browser.closeTabs(.all)
        XCTAssertEqual(browser.tabs.count, 1)
        XCTAssertNotNil(browser.selectedTab)
        XCTAssertEqual(browser.addressDraft, "")
    }

    @MainActor
    func testClearingRegularWebsiteDataDoesNotClearPrivateCookiesOrCloseTabs() throws {
        let browser = makeBrowser()
        browser.newTab(isPrivate: true)
        let privateTab = browser.selectedTab!
        let regularStore = WKWebsiteDataStore.default()
        let privateStore = privateTab.webView.configuration.websiteDataStore
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "acute-data-test.invalid", .path: "/", .name: "acute-fixture", .value: "test",
            .expires: Date().addingTimeInterval(3600)
        ]))
        let stored = expectation(description: "Fixture cookies stored")
        stored.expectedFulfillmentCount = 2
        regularStore.httpCookieStore.setCookie(cookie) { stored.fulfill() }
        privateStore.httpCookieStore.setCookie(cookie) { stored.fulfill() }
        wait(for: [stored], timeout: 15)
        let cleared = expectation(description: "Regular website data cleared")
        browser.clearRegularWebsiteData { cleared.fulfill() }
        wait(for: [cleared], timeout: 15)
        let checked = expectation(description: "Cookie stores checked independently")
        checked.expectedFulfillmentCount = 2
        regularStore.httpCookieStore.getAllCookies { cookies in
            XCTAssertFalse(cookies.contains { $0.name == cookie.name && $0.domain == cookie.domain })
            checked.fulfill()
        }
        privateStore.httpCookieStore.getAllCookies { cookies in
            XCTAssertTrue(cookies.contains { $0.name == cookie.name && $0.domain == cookie.domain })
            checked.fulfill()
        }
        wait(for: [checked], timeout: 15)
        XCTAssertEqual(browser.tabs.count, 2)
        XCTAssertEqual(browser.selectedTabID, privateTab.id)
    }

    @MainActor
    func testDuplicateKeepsWebsiteViewingPreferencesAndPrivateMode() {
        let browser = makeBrowser()
        browser.newTab(isPrivate: true)
        let original = browser.selectedTab!
        original.setPageZoom(1.75)
        original.usesDesktopSite = true
        browser.duplicate(original)
        let duplicate = browser.selectedTab!
        XCTAssertNotEqual(duplicate.id, original.id)
        XCTAssertTrue(duplicate.isPrivate)
        XCTAssertFalse(duplicate.webView.configuration.websiteDataStore.isPersistent)
        XCTAssertEqual(duplicate.pageZoom, 1.75)
        XCTAssertEqual(duplicate.webView.pageZoom, 1.75)
        XCTAssertTrue(duplicate.usesDesktopSite)
        XCTAssertEqual(duplicate.webView.configuration.defaultWebpagePreferences.preferredContentMode, .desktop)
    }

    @MainActor
    func testKeyboardTabSelectionWrapsAndClearsFindAndPermissionRequests() {
        let browser = makeBrowser()
        let first = browser.selectedTab!
        browser.newTab(isPrivate: true)
        let second = browser.selectedTab!
        browser.showsFindBar = true
        var denied = false
        browser.permissionBroker.request(tabID: second.id, host: "private.example", kind: .camera) {
            denied = $0 == .deny
        }
        browser.selectAdjacentTab()
        XCTAssertEqual(browser.selectedTabID, first.id)
        XCTAssertTrue(denied)
        XCTAssertFalse(browser.showsFindBar)
        browser.selectAdjacentTab(backwards: true)
        XCTAssertEqual(browser.selectedTabID, second.id)
        XCTAssertTrue(browser.selectedTab!.isPrivate)
        browser.close(second)
        browser.selectAdjacentTab(backwards: true)
        XCTAssertEqual(browser.selectedTabID, first.id)
    }

    @MainActor
    private func makeBrowser() -> BrowserStore {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return BrowserStore(sessionStore: BrowserSessionStore(defaults: defaults))
    }

    @MainActor
    func testStartPageKeepsTabPositionAndPrivateModeAndDismissesRequests() {
        let browser = makeBrowser()
        browser.newTab(isPrivate: true)
        let oldTab = browser.selectedTab!
        let count = browser.tabs.count
        browser.addressDraft = "https://private.example/"
        browser.showsFindBar = true
        var denied = false
        browser.permissionBroker.request(tabID: oldTab.id, host: "private.example", kind: .camera) {
            denied = $0 == .deny
        }
        browser.showStartPage()
        let replacement = browser.selectedTab!
        XCTAssertEqual(browser.tabs.count, count)
        XCTAssertEqual(browser.tabs.last?.id, replacement.id)
        XCTAssertNotEqual(replacement.id, oldTab.id)
        XCTAssertTrue(replacement.isPrivate)
        XCTAssertFalse(replacement.webView.configuration.websiteDataStore.isPersistent)
        XCTAssertNil(replacement.url)
        XCTAssertEqual(browser.addressDraft, "")
        XCTAssertFalse(browser.showsFindBar)
        XCTAssertTrue(denied)
        XCTAssertTrue(browser.recentlyClosed.isEmpty)
    }

    @MainActor
    func testPageZoomUsesWebKitAndStaysWithinReadableLimits() {
        let tab = BrowserTab()
        tab.setPageZoom(1.5)
        XCTAssertEqual(tab.webView.pageZoom, 1.5)
        tab.setPageZoom(10)
        XCTAssertEqual(tab.pageZoom, 2)
        XCTAssertEqual(tab.webView.pageZoom, 2)
        tab.setPageZoom(-1)
        XCTAssertEqual(tab.pageZoom, 0.5)
        tab.setPageZoom(.nan)
        XCTAssertEqual(tab.pageZoom, 0.5)
        let otherTab = BrowserTab()
        XCTAssertEqual(otherTab.pageZoom, 1)
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
            ["Script blocked", "Script ran"].contains(tab.webView.title ?? "") && !tab.webView.isLoading
        }, evaluatedWith: nil)
        wait(for: [finished], timeout: 30)
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
        wait(for: [loaded], timeout: 60)
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
    func testWebsiteConfirmAndPromptResumeWithTheUsersResponses() {
        let browser = makeBrowser()
        let tab = browser.selectedTab!
        tab.webView.loadHTMLString("<title>Dialog fixture</title>", baseURL: URL(string: "https://acute-dialog-test.invalid/"))
        let loaded = expectation(for: NSPredicate { _, _ in tab.webView.title == "Dialog fixture" }, evaluatedWith: nil)
        wait(for: [loaded], timeout: 60)
        let confirmed = expectation(description: "Website received confirmation")
        tab.webView.evaluateJavaScript("confirm('Continue?')") { value, error in
            XCTAssertNil(error)
            XCTAssertEqual(value as? Bool, true)
            confirmed.fulfill()
        }
        let confirmShown = expectation(for: NSPredicate { _, _ in browser.scriptDialogs.pendingRequest?.kind == .confirm }, evaluatedWith: nil)
        wait(for: [confirmShown], timeout: 5)
        browser.scriptDialogs.resolve(.accept(""))
        wait(for: [confirmed], timeout: 5)

        let prompted = expectation(description: "Website received prompt input")
        tab.webView.evaluateJavaScript("prompt('Name?', 'Default')") { value, error in
            XCTAssertNil(error)
            XCTAssertEqual(value as? String, "Acute")
            prompted.fulfill()
        }
        let promptShown = expectation(for: NSPredicate { _, _ in browser.scriptDialogs.pendingRequest?.kind == .prompt }, evaluatedWith: nil)
        wait(for: [promptShown], timeout: 5)
        XCTAssertEqual(browser.scriptDialogs.pendingRequest?.defaultText, "Default")
        XCTAssertEqual(browser.scriptDialogs.pendingRequest?.host, "acute-dialog-test.invalid")
        browser.scriptDialogs.resolve(.accept("Acute"))
        wait(for: [prompted], timeout: 5)
    }

    @MainActor
    func testClosedPrivateTabsAreNotRetainedForReopeningAndTheirPermissionsAreDenied() {
        let browser = makeBrowser()
        browser.newTab(isPrivate: true)
        let privateTab = browser.selectedTab!
        privateTab.url = URL(string: "https://private.example/secret")
        var denied = false
        browser.permissionBroker.request(tabID: privateTab.id, host: "private.example", kind: .camera) {
            denied = $0 == .deny
        }
        browser.close(privateTab)
        XCTAssertTrue(denied)
        XCTAssertNil(browser.permissionBroker.pendingRequest)
        XCTAssertFalse(browser.recentlyClosed.contains { $0.url?.host == "private.example" })
        browser.newTab()
        let regular = browser.selectedTab!
        regular.url = URL(string: "https://regular.example")
        browser.close(regular)
        XCTAssertEqual(browser.recentlyClosed.first?.url?.host, "regular.example")
    }

    @MainActor
    func testBackgroundingTheAppDeniesPendingPermissionsAndDisallowsWebsitePrompts() {
        let browser = makeBrowser()
        let tab = browser.selectedTab!
        var denied = false
        browser.permissionBroker.request(tabID: tab.id, host: "example.com", kind: .microphone) { denied = $0 == .deny }
        browser.updateSceneActivity(isActive: false)
        XCTAssertTrue(denied)
        XCTAssertFalse(browser.allowsWebsitePrompts)
        browser.updateSceneActivity(isActive: true)
        XCTAssertTrue(browser.allowsWebsitePrompts)
        XCTAssertNil(browser.permissionBroker.pendingRequest)
    }

    @MainActor
    func testTerminatedWebsiteShowsRecoveryAndDeniesPendingPrompts() {
        let browser = makeBrowser()
        browser.newTab(isPrivate: true)
        let tab = browser.selectedTab!
        let requestedURL = URL(string: "https://private.example/recovery")!
        tab.lastRequestedURL = requestedURL
        tab.isLoading = true
        var denied = false
        var dialogCancelled = false
        browser.permissionBroker.request(tabID: tab.id, host: "private.example", kind: .camera) { denied = $0 == .deny }
        browser.scriptDialogs.request(tabID: tab.id, host: "private.example", message: "Continue?", kind: .confirm) {
            if case .cancel = $0 { dialogCancelled = true }
        }
        tab.navigationCoordinator!.webViewWebContentProcessDidTerminate(tab.webView)
        XCTAssertNotNil(tab.navigationError)
        XCTAssertEqual(tab.lastRequestedURL, requestedURL)
        XCTAssertFalse(tab.isLoading)
        XCTAssertTrue(denied)
        XCTAssertTrue(dialogCancelled)
        XCTAssertTrue(tab.isPrivate)
        XCTAssertFalse(tab.webView.configuration.websiteDataStore.isPersistent)
        XCTAssertNil(browser.scriptDialogs.pendingRequest)
        XCTAssertNil(browser.permissionBroker.pendingRequest)
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
