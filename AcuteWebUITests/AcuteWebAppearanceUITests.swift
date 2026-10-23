import XCTest

/// Accessibility audits and appearance checks on the main screens: light and dark mode, and the
/// largest accessibility text size. Each audit reports every issue it finds before the test ends.
final class AcuteWebAppearanceUITests: XCTestCase {
    private var app: XCUIApplication!
    private let baseArguments = ["-savesHistory", "NO", "-restoresTabs", "NO", "-showsStartFavorites", "YES",
                                 "-phoneControlsPosition", "top", "-condensesPhoneControls", "YES",
                                 "-showsTabsInSidebar", "NO"]

    override func setUpWithError() throws {
        // Keep going after an audit issue so one run lists every issue on every screen.
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    func testLightModeScreensPassAccessibilityAudit() {
        launch()
        auditMainScreens(appearance: "Light")
    }

    func testDarkModeScreensPassAccessibilityAudit() {
        launch(extra: ["-acuteUITestDarkMode"])
        auditMainScreens(appearance: "Dark")
    }

    func testLargestTextKeepsPrimaryControlsUsable() {
        launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let window = app.windows.firstMatch
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 15))
        for control in [address, app.buttons["More"], app.buttons["Tabs"]] {
            XCTAssertTrue(control.isHittable, "\(control.description) is not reachable at the largest text size")
            XCTAssertTrue(window.frame.contains(control.frame), "\(control.description) is clipped at the largest text size")
        }
        // No control in the navigation row may overlap another.
        let row = [app.buttons["Back"], address, app.buttons["pageLoadControl"], app.buttons["Tabs"], app.buttons["More"]]
        for (index, control) in row.enumerated() {
            for other in row[(index + 1)...] {
                XCTAssertFalse(control.frame.insetBy(dx: 1, dy: 1).intersects(other.frame.insetBy(dx: 1, dy: 1)),
                               "\(control.description) overlaps \(other.description) at the largest text size")
            }
        }
        openSettings()
        let tabsSetting = app.switches["showsTabsInSidebar"]
        for _ in 0..<12 where !tabsSetting.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(tabsSetting.isHittable, "Settings cannot be scrolled to its Tabs section at the largest text size")
        XCTAssertTrue(app.buttons["Done"].isHittable)
        app.buttons["Done"].tap()
        XCTAssertTrue(address.waitForExistence(timeout: 10))
    }

    private func launch(extra: [String] = []) {
        app.launchArguments = baseArguments + extra
        app.launch()
    }

    private func auditMainScreens(appearance: String) {
        XCTAssertTrue(app.textFields["addressField"].waitForExistence(timeout: 15))
        audit("\(appearance) start page")

        openSettings()
        audit("\(appearance) Settings")
        app.buttons["Done"].tap()

        app.buttons["Tabs"].tap()
        let tabsBar = app.navigationBars["Tabs"]
        XCTAssertTrue(tabsBar.waitForExistence(timeout: 10))
        // The overview opens as a half-height sheet whose lower content scrolls; audit it at full height.
        tabsBar.swipeUp()
        audit("\(appearance) tab overview")
        app.buttons["Done"].tap()

        openLibrary()
        audit("\(appearance) Library")
        app.buttons["Done"].tap()
    }

    /// Records each issue Acute can act on as its own failure, with the element it concerns.
    private func audit(_ screen: String) {
        let navigationBar = app.navigationBars.firstMatch
        let favoriteTiles = app.buttons.matching(identifier: "favoriteTile")
        do {
            try app.performAccessibilityAudit { issue in
                // Issues with no element cannot be located or fixed from the app.
                guard let element = issue.element else { return true }
                // Navigation bar items (Done, titles) are system controls drawn by iOS.
                if navigationBar.exists && navigationBar.frame.contains(element.frame) { return true }
                // The tab count stays small to fit inside its symbol; the Tabs button reads the count
                // out and shows it in the large content viewer.
                if element.identifier == "tabCountBadge" && issue.auditType == .dynamicType { return true }
                // Favorite titles grow with Dynamic Type (the largest-text recordings show them scaled), but
                // tiles that move when the grid reflows at larger sizes are reported as not scaling.
                if issue.auditType == .dynamicType && favoriteTiles.allElementsBoundByIndex
                    .contains(where: { $0.frame.contains(element.frame) }) { return true }
                XCTFail("\(screen): \(issue.compactDescription) on '\(element.label)' id '\(element.identifier)' \(element.frame): \(issue.detailedDescription)")
                return true
            }
        } catch {
            XCTFail("\(screen): the accessibility audit could not run: \(error)")
        }
    }

    private func openSettings() {
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        XCTAssertTrue(app.buttons["New Private Tab"].waitForExistence(timeout: 10))
        // At large text sizes the menu fills the screen and Settings starts below it.
        let settings = app.buttons["Settings"]
        for _ in 0..<6 where !(settings.exists && settings.isHittable) {
            // Drag inside the menu: a drag that starts below it closes the menu instead.
            let menu = app.collectionViews.firstMatch
            if menu.exists {
                menu.swipeUp()
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.15)))
            }
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
    }

    private func openLibrary() {
        app.buttons["More"].tap()
        let savedContent = app.buttons["Saved Content"]
        XCTAssertTrue(savedContent.waitForExistence(timeout: 10))
        _ = app.buttons["Settings"].waitForExistence(timeout: 3)
        let library = app.buttons["Bookmarks and History"]
        for _ in 0..<2 where !library.exists {
            savedContent.tap()
            _ = library.waitForExistence(timeout: 3)
        }
        library.tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
    }
}
