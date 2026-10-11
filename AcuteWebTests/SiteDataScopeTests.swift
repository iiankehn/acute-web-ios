import XCTest
@testable import AcuteWeb

final class SiteDataScopeTests: XCTestCase {
    func testDataScopeIncludesParentDomainAndSubdomainsButNotLookalikes() {
        XCTAssertTrue(SiteDataScope.matches(recordName: "example.com", host: "www.example.com"))
        XCTAssertTrue(SiteDataScope.matches(recordName: "cdn.example.com", host: "example.com"))
        XCTAssertTrue(SiteDataScope.matches(recordName: "EXAMPLE.COM", host: "example.com."))
        XCTAssertFalse(SiteDataScope.matches(recordName: "otherexample.com", host: "example.com"))
        XCTAssertFalse(SiteDataScope.matches(recordName: "example.com.evil", host: "example.com"))
        XCTAssertFalse(SiteDataScope.matches(recordName: "", host: "example.com"))
    }
}
