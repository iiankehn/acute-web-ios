import XCTest
@testable import AcuteWeb

final class WebAddressTests: XCTestCase {
    func testHostnamesPortsAndIPv6ResolveAsWebsiteAddresses() {
        XCTAssertEqual(AddressResolver.resolve("localhost:8080/test")?.absoluteString, "https://localhost:8080/test")
        XCTAssertEqual(AddressResolver.resolve("example.com:8443/path")?.absoluteString, "https://example.com:8443/path")
        XCTAssertEqual(AddressResolver.resolve("[::1]:8080/test")?.port, 8080)
        XCTAssertEqual(AddressResolver.resolve("http://127.0.0.1:8080/test")?.scheme, "http")
    }

    func testUnsupportedSchemesAndInvalidHTTPAddressesDoNotBecomeSearches() {
        for address in ["file:///private/file.txt", "javascript:alert(1)", "data:text/plain,secret", "https://", "http://", "https://example.com:70000/path"] {
            XCTAssertNil(AddressResolver.resolve(address), address)
        }
        XCTAssertNil(RestorableBrowserTab(address: "https://", usesDesktopSite: false).url)
        XCTAssertNil(WebAddress.url("mailto:name@example.com"))
    }

    func testSearchOperatorsAndNormalTextStillUseSelectedProvider() {
        let url = AddressResolver.resolve("site:example.com tablet browser", searchEngine: .brave)!
        XCTAssertEqual(url.host, "search.brave.com")
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(parts.queryItems?.first?.value, "site:example.com tablet browser")
    }
}
