import XCTest
@testable import AcuteWeb

final class SavedSiteSafetyTests: XCTestCase {
    @MainActor
    func testSavedStoresRejectNonWebURLsAndUnsafeLegacyRecords() throws {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let bookmarks = BookmarkStore(defaults: defaults)
        let history = HistoryStore(defaults: defaults)
        for address in ["file:///private/document", "javascript:alert(1)", "about:blank", "data:text/html,hello"] {
            let url = URL(string: address)!
            bookmarks.toggle(title: "Unsafe", url: url)
            history.record(title: "Unsafe", url: url)
            XCTAssertNil(SavedSite(id: UUID(), title: "Unsafe", address: address, savedAt: Date()).url)
        }
        XCTAssertTrue(bookmarks.items.isEmpty)
        XCTAssertTrue(history.items.isEmpty)
        let records = [
            SavedSite(id: UUID(), title: "Bad", address: "file:///private/document", savedAt: Date()),
            SavedSite(id: UUID(), title: "Good", address: "https://example.com", savedAt: Date())
        ]
        let data = try JSONEncoder().encode(records)
        defaults.set(data, forKey: "bookmarks")
        defaults.set(data, forKey: "history")
        XCTAssertEqual(BookmarkStore(defaults: defaults).items.map(\.title), ["Good"])
        XCTAssertEqual(HistoryStore(defaults: defaults).items.map(\.title), ["Good"])
    }

    @MainActor
    func testHistoryDeduplicatesPersistsAndClearsOnlyHistory() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = HistoryStore(defaults: defaults)
        let bookmarks = BookmarkStore(defaults: defaults)
        let url = URL(string: "https://example.com")!
        bookmarks.toggle(title: "", url: url)
        history.record(title: "Old", url: url)
        history.record(title: "   ", url: url)
        XCTAssertEqual(history.items.count, 1)
        XCTAssertEqual(HistoryStore(defaults: defaults).items[0].title, "example.com")
        history.clear()
        XCTAssertTrue(HistoryStore(defaults: defaults).items.isEmpty)
        XCTAssertEqual(BookmarkStore(defaults: defaults).items.count, 1)
    }
}
