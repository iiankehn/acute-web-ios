import XCTest

/// Native surfaces only. External website accessibility is outside these audits.
final class BetaAccessibilityTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-savesHistory", "NO", "-restoresTabs", "NO",
            "-showsStartBookmarks", "NO", "-showsStartRecentSites", "NO",
            "-showsStartFavorites", "YES", "-phoneControlsPosition", "top",
            "-condensesPhoneControls", "YES"
        ]
        app.launch()
    }

    @MainActor
    func testStartPageAccessibility() throws {
        XCTAssertTrue(app.staticTexts["The web, in focus."].waitForExistence(timeout: 10))
        try auditVisibleNativeContent()
    }

    @MainActor
    func testSettingsAccessibility() throws {
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 10))
        app.buttons["More"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try auditVisibleNativeContent()

        let policy = app.buttons["privacyPolicyLink"]
        for _ in 0..<8 {
            if policy.exists && policy.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(policy.isHittable)
        try auditVisibleNativeContent()
        app.buttons["Done"].tap()
    }

    @MainActor
    private func auditVisibleNativeContent() throws {
        // Do not silently suppress audit issues. Investigate reported elements
        // before adding any narrowly explained exception.
        try app.performAccessibilityAudit(for: [
            .contrast, .dynamicType, .hitRegion, .sufficientElementDescription,
            .textClipped, .trait
        ])
    }
}
