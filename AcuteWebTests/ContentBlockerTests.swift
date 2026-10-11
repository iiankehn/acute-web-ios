import XCTest
import WebKit
@testable import AcuteWeb

final class ContentBlockerTests: XCTestCase {
    @MainActor
    func testResourceFiltersMatchTrackerHostsWithoutMatchingLookalikes() throws {
        for domain in ContentBlocker.trackerDomains {
            let regex = try NSRegularExpression(pattern: ContentBlocker.resourceFilter(for: domain), options: .caseInsensitive)
            func matches(_ value: String) -> Bool {
                regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
            }
            XCTAssertTrue(matches("https://\(domain)/script.js"))
            XCTAssertTrue(matches("http://sub.\(domain):8080/resource"))
            XCTAssertFalse(matches("https://\(domain).unrelated.example/script.js"))
            XCTAssertFalse(matches("https://unrelated.example/\(domain)/script.js"))
        }
    }

    @MainActor
    func testWebKitCompilesResourceBlockingRules() {
        let compiled = expectation(description: "WebKit compiled tracker resource rules")
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "AcutePrivacyRules-tests", encodedContentRuleList: ContentBlocker.rules) { list, error in
            XCTAssertNil(error)
            XCTAssertNotNil(list)
            compiled.fulfill()
        }
        wait(for: [compiled], timeout: 15)
    }
}
