import XCTest
import SwiftUI
@testable import AcuteWeb

final class BrowserChromeModeTests: XCTestCase {
    func testSystemVerticalBarsMoveControlsToARailRegardlessOfWidth() {
        for sizeClass in [UserInterfaceSizeClass.compact, .regular, nil] {
            XCTAssertEqual(BrowserChromeMode.resolve(horizontalSizeClass: sizeClass, verticalBarEdge: .trailing,
                                                     prefersBottomControls: true), .rail(.trailing))
        }
        XCTAssertEqual(BrowserChromeMode.resolve(horizontalSizeClass: .compact, verticalBarEdge: .leading,
                                                 prefersBottomControls: false).railEdge, .leading)
    }

    func testWidthDecidesTheRowWithoutVerticalBars() {
        let wide = BrowserChromeMode.resolve(horizontalSizeClass: .regular, verticalBarEdge: nil, prefersBottomControls: true)
        XCTAssertEqual(wide, .wideRow)
        XCTAssertFalse(wide.controlsAtBottom, "Wide windows keep navigation at the top")
        let bottom = BrowserChromeMode.resolve(horizontalSizeClass: .compact, verticalBarEdge: nil, prefersBottomControls: true)
        XCTAssertTrue(bottom.controlsAtBottom)
        XCTAssertNil(bottom.railEdge)
        XCTAssertFalse(BrowserChromeMode.resolve(horizontalSizeClass: .compact, verticalBarEdge: nil,
                                                 prefersBottomControls: false).controlsAtBottom)
    }

    func testVerticalFoldSplitsWindowIntoBookHalves() {
        let size = CGSize(width: 951, height: 669)
        let fold = CGRect(x: 455, y: 0, width: 41, height: 669)
        XCTAssertEqual(FoldLayout.resolve(divisions: [fold], in: size), .book(leadingEnd: 455, trailingStart: 496))
    }

    func testHorizontalFoldIsTabletop() {
        let size = CGSize(width: 669, height: 951)
        let fold = CGRect(x: -10, y: 455, width: 700, height: 41)
        XCTAssertEqual(FoldLayout.resolve(divisions: [fold], in: size), .tabletop(topEnd: 455, bottomStart: 496))
    }

    func testNoActiveOrOutOfBoundsDivisionMeansNoFold() {
        let size = CGSize(width: 669, height: 951)
        XCTAssertEqual(FoldLayout.resolve(divisions: [], in: size), .none)
        XCTAssertEqual(FoldLayout.resolve(divisions: [CGRect(x: 800, y: 0, width: 40, height: 951)], in: size), .none)
        // A division along an edge does not leave two usable halves.
        XCTAssertEqual(FoldLayout.resolve(divisions: [CGRect(x: 0, y: 0, width: 30, height: 951)], in: size), .none)
    }

    @MainActor
    func testTabsInSidebarIsOffByDefaultAndPersists() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = BrowserPreferences(defaults: defaults)
        XCTAssertFalse(preferences.showsTabsInSidebar)
        preferences.showsTabsInSidebar = true
        XCTAssertTrue(BrowserPreferences(defaults: defaults).showsTabsInSidebar)
    }
}
