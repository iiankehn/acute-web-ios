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
    func testEveryTextSizeScalesFavoritesAndSettingsDescriptions() throws {
        let baseArguments = app.launchArguments
        let categories: [UIContentSizeCategory] = [
            .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge,
            .extraExtraExtraLarge, .accessibilityMedium, .accessibilityLarge,
            .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
            .accessibilityExtraExtraExtraLarge
        ]
        var previous: [String: CGFloat] = [:]
        var smallest: [String: CGFloat] = [:]
        for category in categories {
            app.terminate()
            app.launchArguments = baseArguments + ["-UIPreferredContentSizeCategoryName", category.rawValue]
            app.launch()
            XCTAssertTrue(app.buttons["Tabs"].waitForExistence(timeout: 10))
            XCTAssertEqual(app.buttons["Tabs"].value as? String, "1 open")
            for name in ["Wikipedia", "GitHub", "DuckDuckGo"] {
                let title = app.staticTexts["favoriteTitle_\(name)"]
                scrollTo(title)
                checkTextGrowth(title, category: category, previous: &previous, smallest: &smallest)
            }
            app.buttons["More"].tap()
            app.buttons["Settings"].tap()
            let description = app.staticTexts["browsingLayoutExplanation"]
            scrollTo(description)
            checkTextGrowth(description, category: category, previous: &previous, smallest: &smallest)
            XCTAssertTrue(app.buttons["Done"].isHittable)
            app.buttons["Done"].tap()
        }
    }

    @MainActor
    private func checkTextGrowth(_ element: XCUIElement, category: UIContentSizeCategory,
                                 previous: inout [String: CGFloat], smallest: inout [String: CGFloat]) {
        let identifier = element.identifier
        let height = element.frame.height
        XCTAssertGreaterThan(height, 0)
        if let previousHeight = previous[identifier] {
            XCTAssertGreaterThan(height, previousHeight, "\(identifier) did not grow at \(category.rawValue)")
        } else {
            smallest[identifier] = height
        }
        if category == .accessibilityExtraExtraExtraLarge, let minimum = smallest[identifier] {
            XCTAssertGreaterThan(height, minimum * 1.5)
        }
        print("TEXT SIZE EVIDENCE: \(identifier), category=\(category.rawValue), height=\(height)")
        previous[identifier] = height
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
        // Run contrast before Dynamic Type mutates the screen's typography.
        // Keep failures independent so one category cannot hide later findings.
        let audits: [XCUIAccessibilityAuditType] = [
            .contrast, .hitRegion, .sufficientElementDescription,
            .textClipped, .trait, .dynamicType
        ]
        for audit in audits {
            try app.performAccessibilityAudit(for: audit) { issue in
                print("ACCESSIBILITY AUDIT: \(issue.compactDescription) — \(issue.detailedDescription)")
                if let element = issue.element, element.exists {
                    print("AUDIT ELEMENT: \(element.elementType), label=\(element.label), id=\(element.identifier), frame=\(element.frame)")
                }
                return false // Never mark an issue handled or suppress its failure.
            }
        }
    }
}
