import XCTest
@testable import AcuteWeb

final class SavedSiteSearchTests: XCTestCase {
    func testSearchMatchesTitlesAndFullAddressesIgnoringCaseAndWhitespace() {
        let site = SavedSite(id: UUID(), title: "Swift Documentation", address: "https://swift.org/documentation", savedAt: Date())
        XCTAssertTrue(site.matchesSearch("  SWIFT DOCUMENTATION \n"))
        XCTAssertTrue(site.matchesSearch("SWIFT.ORG"))
        XCTAssertTrue(site.matchesSearch("/documentation"))
        XCTAssertTrue(site.matchesSearch("  "))
        XCTAssertFalse(site.matchesSearch("unrelated"))
    }
}
