import XCTest

/// Runs only in the iPad and iPhone Duo CI jobs, which set TEST_RUNNER_ACUTE_LAYOUT_TESTS.
/// The simulator's pose is whatever it boots in, so each test checks the layout the window calls for,
/// in portrait and in landscape.
final class AcuteWebLayoutUITests: XCTestCase {
    private var app: XCUIApplication!
    private let orientations: [UIDeviceOrientation] = [.portrait, .landscapeLeft]

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ACUTE_LAYOUT_TESTS"] == "1",
                          "Layout checks run only on the iPad and iPhone Duo simulators")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    /// Each test launches the app itself, so none has to terminate and relaunch it to change a setting.
    private func launch(showsTabsInSidebar: Bool = false) {
        app.launchArguments = ["-savesHistory", "NO", "-restoresTabs", "NO", "-condensesPhoneControls", "NO",
                               "-showsTabsInSidebar", showsTabsInSidebar ? "YES" : "NO"]
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testNavigationControlsFollowTheSystemBarPlacement() {
        launch()
        for orientation in orientations {
            rotate(to: orientation)
            let address = app.textFields["addressField"]
            XCTAssertTrue(address.waitForExistence(timeout: 15))
            let rail = app.otherElements["navigationRail"]
            let back = app.buttons["Back"]
            let more = app.buttons["More"]
            XCTAssertTrue(back.exists)
            XCTAssertTrue(more.isHittable, "More is unreachable in \(orientation.rawValue)")
            XCTAssertTrue(address.isHittable, "The address is unreachable in \(orientation.rawValue)")
            if rail.exists {
                // Side rail: Back and More sit on the rail, beside the capsule row rather than in it.
                XCTAssertTrue(rail.frame.contains(CGPoint(x: back.frame.midX, y: back.frame.midY)))
                XCTAssertTrue(rail.frame.contains(CGPoint(x: more.frame.midX, y: more.frame.midY)))
                XCTAssertFalse(rail.frame.intersects(address.frame))
                XCTAssertGreaterThan(rail.frame.height, rail.frame.width * 3)
            } else {
                // Horizontal bars: navigation stays in the capsule row.
                XCTAssertEqual(back.frame.midY, address.frame.midY, accuracy: 2)
                XCTAssertEqual(more.frame.midY, address.frame.midY, accuracy: 2)
            }
            XCTAssertTrue(app.windows.firstMatch.frame.contains(more.frame), "More is clipped in \(orientation.rawValue)")
        }
    }

    func testMoreMenuTabActionsWorkInEveryOrientation() {
        launch()
        for (index, orientation) in orientations.enumerated() {
            rotate(to: orientation)
            app.buttons["More"].tap()
            let privateTab = app.buttons["New Private Tab"]
            XCTAssertTrue(privateTab.waitForExistence(timeout: 10),
                          "More has no tab actions in \(orientation.rawValue)")
            // Choosing an action closes the menu, which an outside tap did not do reliably.
            privateTab.tap()
            XCTAssertTrue(app.buttons["Settings"].waitForNonExistence(timeout: 10))
            let opened = NSPredicate(format: "value == %@", "\(index + 2) open")
            let tabs = XCTNSPredicateExpectation(predicate: opened, object: app.buttons["Tabs"])
            XCTAssertEqual(XCTWaiter.wait(for: [tabs], timeout: 10), .completed,
                           "New Private Tab did not open a tab in \(orientation.rawValue)")
        }
    }

    func testRailActionsStayUsable() throws {
        launch()
        let rail = app.otherElements["navigationRail"]
        guard rail.waitForExistence(timeout: 10) else {
            throw XCTSkip("This pose uses horizontal bars")
        }
        app.buttons["New Tab"].tap()
        let tabs = app.buttons["Tabs"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        XCTAssertEqual(tabs.value as? String, "2 open")
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["New Private Tab"].waitForExistence(timeout: 5))
    }

    func testWideWindowSidebarShowsTheLibraryNotTabs() throws {
        launch()
        let sidebar = try showSidebar()
        XCTAssertTrue(sidebar.exists)
        XCTAssertTrue(app.segmentedControls["sidebarLibraryPicker"].exists)
        XCTAssertFalse(app.staticTexts["Tabs"].exists)
    }

    func testShowTabsInSidebarAddsATabsSection() throws {
        launch(showsTabsInSidebar: true)
        _ = try showSidebar()
        XCTAssertTrue(app.staticTexts["Tabs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Library"].exists)
        XCTAssertTrue(app.segmentedControls["sidebarLibraryPicker"].exists)
    }

    private func rotate(to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 10))
        // Wait for the rotation to settle before reading frames.
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"),
                                                object: app.buttons["More"])
        _ = XCTWaiter.wait(for: [settled], timeout: 5)
    }

    /// Landscape gives wide windows room for the sidebar; skips where the window stays compact.
    private func showSidebar() throws -> XCUIElement {
        rotate(to: .landscapeLeft)
        let sidebar = app.descendants(matching: .any).matching(identifier: "browserSidebar").firstMatch
        guard sidebar.waitForExistence(timeout: 10) else {
            throw XCTSkip("The sidebar appears only in wide windows")
        }
        return sidebar
    }
}
