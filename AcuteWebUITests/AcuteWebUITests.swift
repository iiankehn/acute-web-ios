import XCTest

final class AcuteWebUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-savesHistory", "NO", "-restoresTabs", "NO"]
        app.launch()
    }

    func testLaunchShowsNativeStartPage() {
        XCTAssertTrue(app.staticTexts["Acute Web"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["The web, in focus."].exists)
        XCTAssertTrue(app.textFields["addressField"].exists)
        attachScreenshot("Start Page")
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
        XCTAssertTrue(app.staticTexts["Acute telemetry"].exists)
        XCTAssertTrue(app.staticTexts["None"].exists)
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
        XCTAssertTrue(restoreSwitch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS 'Private tabs are never saved or restored'"
        )).firstMatch.exists)
        attachScreenshot("Session Recovery")
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
