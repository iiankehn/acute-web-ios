import XCTest
import UIKit
@testable import AcuteWeb

final class BrowserChromeLayoutTests: XCTestCase {
    @MainActor
    func testChangingChromeHeightKeepsPageTopAccessibleAndPreservesOtherInsets() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        scroll.contentSize = CGSize(width: 800, height: 2000)
        scroll.contentInset = UIEdgeInsets(top: 110, left: 4, bottom: 34, right: 6)
        scroll.verticalScrollIndicatorInsets.bottom = 34
        scroll.contentOffset = CGPoint(x: 20, y: -110)
        BrowserChromeLayout.apply(topInset: 60, to: scroll)
        XCTAssertEqual(scroll.contentOffset, CGPoint(x: 20, y: -60))
        XCTAssertEqual(scroll.contentInset, UIEdgeInsets(top: 60, left: 4, bottom: 34, right: 6))
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets.top, 60)
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets.bottom, 34)
        BrowserChromeLayout.apply(topInset: 160, to: scroll)
        XCTAssertEqual(scroll.contentOffset.y, -160)
    }

    @MainActor
    func testScrolledPageDoesNotJumpWhenChromeChangesAndInvalidHeightIsIgnored() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        scroll.contentSize = CGSize(width: 390, height: 2000)
        scroll.contentInset.top = 110
        scroll.contentOffset.y = 300
        BrowserChromeLayout.apply(topInset: 60, to: scroll)
        XCTAssertEqual(scroll.contentOffset.y, 300)
        BrowserChromeLayout.apply(topInset: .nan, to: scroll)
        XCTAssertEqual(scroll.contentInset.top, 60)
        BrowserChromeLayout.apply(topInset: -20, to: scroll)
        XCTAssertEqual(scroll.contentInset.top, 0)
        XCTAssertEqual(scroll.contentOffset.y, 300)
    }
}
