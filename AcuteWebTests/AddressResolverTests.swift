import XCTest
@testable import AcuteWeb

final class AddressResolverTests: XCTestCase {
    func testPreservesHTTPSURL() {
        XCTAssertEqual(AddressResolver.resolve("https://example.com/path")?.absoluteString,
                       "https://example.com/path")
    }

    func testAddsHTTPSForHost() {
        XCTAssertEqual(AddressResolver.resolve("example.com")?.absoluteString,
                       "https://example.com")
    }

    func testSearchesWordsPrivately() {
        let url = AddressResolver.resolve("acute web browser")
        XCTAssertEqual(url?.host, "duckduckgo.com")
        XCTAssertEqual(URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value,
                       "acute web browser")
    }
}

