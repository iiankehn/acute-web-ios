import XCTest
import WebKit
@testable import AcuteWeb

final class ExternalLinkTests: XCTestCase {
    func testOnlyActivatedTopLevelAllowlistedLinksAreEligible() {
        for address in ["mailto:hello@example.com", "tel:+15555550123", "sms:+15555550123"] {
            let url = URL(string: address)!
            XCTAssertTrue(ExternalLinkPolicy.allows(url, navigationType: .linkActivated, isMainFrame: true))
            XCTAssertFalse(ExternalLinkPolicy.allows(url, navigationType: .other, isMainFrame: true))
            XCTAssertFalse(ExternalLinkPolicy.allows(url, navigationType: .linkActivated, isMainFrame: false))
        }
        for address in ["file:///private/document", "javascript:alert(1)", "custom:payload", "https://example.com", "tel:"] {
            XCTAssertFalse(ExternalLinkPolicy.allows(URL(string: address)!, navigationType: .linkActivated, isMainFrame: true))
        }
    }

    @MainActor
    private func makeBrowser() -> BrowserStore {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return BrowserStore(sessionStore: BrowserSessionStore(defaults: defaults), preferences: BrowserPreferences(defaults: defaults))
    }

    @MainActor
    func testExternalLinkDoesNotOpenUntilApprovedAndPreservesWebsiteRetryAddress() {
        let browser = makeBrowser()
        let tab = browser.selectedTab!
        let website = URL(string: "https://example.com")!
        tab.lastRequestedURL = website
        let link = URL(string: "mailto:hello@example.com")!
        var opened: [URL] = []
        XCTAssertTrue(tab.navigationCoordinator!.requestExternalLink(link, navigationType: .linkActivated, isMainFrame: true) { opened.append($0) })
        XCTAssertTrue(opened.isEmpty)
        XCTAssertEqual(browser.scriptDialogs.pendingRequest?.kind, .externalLink)
        browser.scriptDialogs.resolve(.accept(""))
        XCTAssertEqual(opened, [link])
        XCTAssertEqual(tab.lastRequestedURL, website)
    }

    @MainActor
    func testPrivateLinkWarnsAndTabSwitchCancelsOpening() {
        let browser = makeBrowser()
        browser.newTab(isPrivate: true)
        let tab = browser.selectedTab!
        var opened = false
        tab.navigationCoordinator!.requestExternalLink(URL(string: "sms:+15555550123")!, navigationType: .linkActivated, isMainFrame: true) { _ in opened = true }
        let request = browser.scriptDialogs.pendingRequest!
        XCTAssertTrue(request.message.contains("Private browsing protection does not extend"))
        browser.newTab()
        XCTAssertNil(browser.scriptDialogs.pendingRequest)
        browser.scriptDialogs.resolve(.accept(""), requestID: request.id)
        XCTAssertFalse(opened)
    }

    @MainActor
    func testBackgroundTabsCannotRequestExternalOpening() {
        let browser = makeBrowser()
        let tab = browser.selectedTab!
        browser.updateSceneActivity(isActive: false)
        var opened = false
        XCTAssertFalse(tab.navigationCoordinator!.requestExternalLink(URL(string: "tel:+15555550123")!, navigationType: .linkActivated, isMainFrame: true) { _ in opened = true })
        XCTAssertFalse(opened)
        XCTAssertNil(browser.scriptDialogs.pendingRequest)
    }

    @MainActor
    func testInvalidAddressReportsFeedbackWithoutNavigating() {
        let browser = makeBrowser()
        browser.addressDraft = "javascript:alert(1)"
        browser.navigate()
        XCTAssertNotNil(browser.addressInputError)
        XCTAssertNil(browser.selectedTab?.lastRequestedURL)
        browser.newTab()
        XCTAssertNil(browser.addressInputError)
        browser.addressDraft = " "
        browser.navigate()
        XCTAssertNil(browser.addressInputError)
    }
}
