import XCTest

/// Runs only in the iPhone Duo CI job, which sets TEST_RUNNER_ACUTE_IPHONE_DUO.
/// The simulator's pose is whatever it boots in, so each test checks the layout that pose calls for.
final class AcuteWebDuoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ACUTE_IPHONE_DUO"] == "1",
                          "iPhone Duo layout checks run only on the iPhone Duo simulator")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-savesHistory", "NO", "-restoresTabs", "NO", "-condensesPhoneControls", "NO",
                               "-showsTabsInSidebar", "NO"]
        app.launch()
    }

    func testNavigationControlsFollowTheSystemBarPlacement() {
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 15))
        let rail = app.otherElements["navigationRail"]
        let back = app.buttons["Back"]
        let more = app.buttons["More"]
        XCTAssertTrue(back.exists)
        XCTAssertTrue(more.exists)
        if rail.exists {
            // Side rail: Back and More sit on the rail, beside the capsule row rather than in it.
            XCTAssertTrue(rail.frame.contains(CGPoint(x: back.frame.midX, y: back.frame.midY)))
            XCTAssertTrue(rail.frame.contains(CGPoint(x: more.frame.midX, y: more.frame.midY)))
            XCTAssertFalse(rail.frame.intersects(address.frame))
            XCTAssertGreaterThan(rail.frame.height, rail.frame.width * 3)
        } else {
            // Horizontal bars (open in portrait): navigation stays in the capsule row.
            XCTAssertEqual(back.frame.midY, address.frame.midY, accuracy: 2)
            XCTAssertEqual(more.frame.midY, address.frame.midY, accuracy: 2)
        }
    }

    func testRailActionsStayUsable() throws {
        let rail = app.otherElements["navigationRail"]
        guard rail.waitForExistence(timeout: 10) else {
            throw XCTSkip("This pose uses horizontal bars")
        }
        app.buttons["New Tab"].tap()
        let tabs = app.buttons["Tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        XCTAssertEqual(tabs.value as? String, "2 open")
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Tab Management"].waitForExistence(timeout: 5))
    }

    func testWideWindowSidebarShowsTheLibraryNotTabs() throws {
        let sidebar = app.descendants(matching: .any).matching(identifier: "browserSidebar").firstMatch
        guard sidebar.waitForExistence(timeout: 10) else {
            throw XCTSkip("The sidebar appears only in wide windows")
        }
        XCTAssertTrue(app.segmentedControls["sidebarLibraryPicker"].exists)
        XCTAssertFalse(app.staticTexts["Tabs"].exists)
    }
}
