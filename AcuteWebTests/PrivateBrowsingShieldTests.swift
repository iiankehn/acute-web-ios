import XCTest
import UIKit
@testable import AcuteWeb

final class PrivateBrowsingShieldTests: XCTestCase {
    @MainActor
    func testShieldCoversModalContentAndIsRemovedWhenBrowsingResumes() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let modal = UIView(frame: window.bounds)
        window.addSubview(modal)
        let shield = PrivateBrowsingShield.Coordinator()
        shield.isEnabled = true
        shield.update(window: window)
        XCTAssertEqual(window.subviews.last?.accessibilityIdentifier, "privateBrowsingCover")
        XCTAssertEqual(window.subviews.last?.frame, window.bounds)
        window.addSubview(UIView(frame: window.bounds))
        shield.update(window: window)
        XCTAssertEqual(window.subviews.last?.accessibilityIdentifier, "privateBrowsingCover")
        shield.isEnabled = false
        shield.update(window: window)
        XCTAssertFalse(window.subviews.contains { $0.accessibilityIdentifier == "privateBrowsingCover" })
    }
}
