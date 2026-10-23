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
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 10))
        audit("\(appearance) tab overview")
        app.buttons["Done"].tap()

        openLibrary()
        audit("\(appearance) Library")
        app.buttons["Done"].tap()
    }

    /// Records each issue as its own failure, with the element it concerns.
    private func audit(_ screen: String) {
        do {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { "'\($0.label)' id '\($0.identifier)'" } ?? "no element"
                XCTFail("\(screen): \(issue.compactDescription) (\(issue.auditType.rawValue)) on \(element)")
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
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
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
