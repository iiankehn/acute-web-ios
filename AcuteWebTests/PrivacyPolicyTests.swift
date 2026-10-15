import XCTest
@testable import AcuteWeb

final class PrivacyPolicyTests: XCTestCase {
    func testPolicyIsBundledForOfflineReading() throws {
        let text = try XCTUnwrap(PrivacyPolicy.text)
        XCTAssertTrue(text.contains("Privacy Policy"))
        XCTAssertTrue(text.contains("device backups"))
        XCTAssertTrue(text.contains("Retention and deletion"))
        XCTAssertTrue(text.contains(PrivacyPolicy.supportURL.absoluteString))
    }

    func testPolicyAndSupportLinksUseProjectHTTPSURLs() {
        for url in [PrivacyPolicy.publicURL, PrivacyPolicy.supportURL] {
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "github.com")
            XCTAssertTrue(url.path.hasPrefix("/iiankehn/acute-web-ios/"))
        }
    }
}
