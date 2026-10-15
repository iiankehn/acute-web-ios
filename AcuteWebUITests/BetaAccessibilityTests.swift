import XCTest
import UIKit

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
    func testLargestTextScalesFavoritesAndSettingsDescriptions() throws {
        let title = app.staticTexts["favoriteTitle_GitHub"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let normalTitleHeight = title.frame.height
        app.buttons["More"].tap()
        app.buttons["Settings"].tap()
        let description = app.staticTexts["browsingLayoutExplanation"]
        scrollTo(description)
        let normalDescriptionHeight = description.frame.height
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName",
                                UIContentSizeCategory.accessibilityExtraExtraExtraLarge.rawValue]
        app.launch()
        scrollTo(title)
        XCTAssertGreaterThan(title.frame.height, normalTitleHeight * 1.5)
        XCTAssertTrue(title.isHittable)
        app.buttons["More"].tap()
        app.buttons["Settings"].tap()
        scrollTo(description)
        XCTAssertGreaterThan(description.frame.height, normalDescriptionHeight * 1.5)
        XCTAssertTrue(app.buttons["Done"].isHittable)
        app.buttons["Done"].tap()
    }

    @MainActor
    func testStartPageAccessibility() throws {
        XCTAssertTrue(app.staticTexts["The web, in focus."].waitForExistence(timeout: 10))
        try auditVisibleNativeContent()
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<16 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
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
        // Log every issue for diagnosis while leaving all failures intact.
        let previousContinuation = continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = previousContinuation }
        try app.performAccessibilityAudit(for: [
            .contrast, .dynamicType, .hitRegion, .sufficientElementDescription,
            .textClipped, .trait
        ]) { issue in
            print("ACCESSIBILITY AUDIT: \(issue.compactDescription) — \(issue.detailedDescription)")
            if let element = issue.element, element.exists {
                print("AUDIT ELEMENT: \(element.elementType), label=\(element.label), id=\(element.identifier), frame=\(element.frame)")
            }
            return false // Never mark an issue handled or suppress its failure.
        }
    }
}
