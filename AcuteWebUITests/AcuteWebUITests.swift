import XCTest

final class AcuteWebUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-savesHistory", "NO", "-restoresTabs", "NO", "-showsStartFavorites", "YES"]
        app.launch()
    }

    func testLaunchShowsNativeStartPage() {
        XCTAssertTrue(app.staticTexts["Acute Web"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["The web, in focus."].exists)
        XCTAssertTrue(app.textFields["addressField"].exists)
        attachScreenshot("Start Page")
    }

    func testUnsupportedTypedAddressShowsClearFeedback() {
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        address.tap()
        address.typeText("javascript:alert(1)\n")
        XCTAssertTrue(app.alerts["Unable to Open Address"].waitForExistence(timeout: 5))
        app.alerts["Unable to Open Address"].buttons["OK"].tap()
        XCTAssertTrue(app.staticTexts["The web, in focus."].exists)
    }

    func testCompactToolbarKeepsAddressAndMenuUsableAfterRotation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(address.frame.width, 180)
        XCTAssertTrue(app.buttons["More"].isHittable)
        XCTAssertTrue(app.buttons["Tabs"].isHittable)
        attachScreenshot("iPhone Portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5))
        XCTAssertTrue(address.isHittable)
        XCTAssertGreaterThan(address.frame.width, 180)
        XCTAssertTrue(app.buttons["More"].isHittable)
        attachScreenshot("iPhone Landscape")
        openMoreMenu()
        XCTAssertTrue(app.buttons["New Private Tab"].waitForExistence(timeout: 5))
    }

    func testTabSwitcherCreatesPrivateTabsAndClosesLastTab() {
        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 5))
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selectTab_'"))
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.firstMatch.value as? String, "Selected tab")
        attachScreenshot("Tab Switcher")

        app.buttons["New Tab Options"].tap()
        app.buttons["New Private Tab"].tap()
        XCTAssertTrue(app.staticTexts["Private browsing"].waitForExistence(timeout: 5))
        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 5))
        XCTAssertEqual(cards.count, 2)
        attachScreenshot("Private Tab Switcher")

        let closeButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'closeTab_'"))
        closeButtons.firstMatch.tap()
        XCTAssertEqual(cards.count, 1)
        closeButtons.firstMatch.tap()
        XCTAssertEqual(cards.count, 1)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["The web, in focus."].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["addressField"].value as? String, "Search or enter address")
    }

    func testPrivacySettingsDefaultToNoHistory() {
        openMoreMenu()
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let telemetry = app.descendants(matching: .any).matching(identifier: "telemetryStatus").firstMatch
        scrollTo(telemetry)
        XCTAssertEqual(telemetry.label, "Acute telemetry")
        XCTAssertEqual(telemetry.value as? String, "None")
        let historySwitch = app.switches["Save browsing history"]
        XCTAssertTrue(historySwitch.exists)
        XCTAssertEqual(historySwitch.value as? String, "0")
        attachScreenshot("Privacy Settings")
    }

    func testPrivateTabUsesPrivateStartPage() {
        openMoreMenu()
        app.buttons["New Private Tab"].tap()

        XCTAssertTrue(app.staticTexts["Private browsing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'non-persistent WebKit data store'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Favorites"].exists)
        XCTAssertFalse(app.staticTexts["Bookmarks"].exists)
        attachScreenshot("Private Browsing")
    }

    func testLibraryExposesBookmarksAndHistory() {
        openMoreMenu()
        app.buttons["Bookmarks and History"].tap()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Bookmarks"].exists)
        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No History"].waitForExistence(timeout: 5))
        attachScreenshot("History Off")
    }

    func testSessionRecoveryExplainsPrivateTabExclusion() {
        openMoreMenu()
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let restoreSwitch = app.switches["Restore regular tabs"]
        scrollTo(restoreSwitch)
        XCTAssertEqual(restoreSwitch.value as? String, "0")
        let explanation = app.staticTexts["sessionRecoveryExplanation"]
        scrollTo(explanation)
        XCTAssertTrue(explanation.label.contains("Private tabs are never saved or restored"))
        attachScreenshot("Session Recovery")
    }

    func testStartPageCustomizationUpdatesImmediately() {
        openMoreMenu()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let favorites = app.switches["Show favorites"]
        scrollTo(favorites)
        setSwitch(favorites, enabled: false)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.textFields["startSearchField"].waitForExistence(timeout: 5))
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["Favorites"])
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)

        openMoreMenu()
        app.buttons["Settings"].tap()
        scrollTo(favorites)
        setSwitch(favorites, enabled: true)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Favorites"].waitForExistence(timeout: 5))
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    func testBulkPrivateTabClosingRequiresConfirmation() {
        openMoreMenu()
        app.buttons["New Private Tab"].tap()
        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 5))
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selectTab_'"))
        XCTAssertEqual(cards.count, 2)
        app.buttons["Tab Actions"].tap()
        app.buttons["Close Private Tabs"].tap()
        let confirmation = app.alerts["Close Private Tabs"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.buttons["Cancel"].exists)
        confirmation.buttons["Cancel"].tap()
        XCTAssertEqual(cards.count, 2)
        app.buttons["Tab Actions"].tap()
        app.buttons["Close Private Tabs"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Close Private Tabs"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in cards.count == 1 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["The web, in focus."].waitForExistence(timeout: 5))
    }

    func testClearingWebsiteDataRequiresConfirmationAndCanBeCancelled() {
        openMoreMenu()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let clear = app.buttons["Clear Regular Website Data"]
        scrollTo(clear)
        clear.tap()
        let confirmation = app.alerts["Clear Regular Website Data?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.buttons["Clear Website Data"].exists)
        confirmation.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Regular website data cleared"].exists)
        XCTAssertTrue(clear.exists)
    }

    private func setSwitch(_ element: XCUIElement, enabled: Bool) {
        let expected = enabled ? "1" : "0"
        if element.value as? String != expected {
            // Tap the trailing switch control rather than the center of its labeled Form row.
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    private func openMoreMenu() {
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
