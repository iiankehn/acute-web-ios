import XCTest
@testable import AcuteWeb

final class BookmarkStoreTests: XCTestCase {
    @MainActor
    func testEditingPreservesIdentityAndPersistsTheNewTitleAndAddress() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = BookmarkStore(defaults: defaults)
        store.toggle(title: "Original", url: URL(string: "https://example.com")!)
        let original = store.items[0]
        XCTAssertTrue(store.update(original, title: "  Renamed  ", address: "example.org/path"))
        let recovered = BookmarkStore(defaults: defaults)
        XCTAssertEqual(recovered.items[0].id, original.id)
        XCTAssertEqual(recovered.items[0].savedAt, original.savedAt)
        XCTAssertEqual(recovered.items[0].title, "Renamed")
        XCTAssertEqual(recovered.items[0].address, "https://example.org/path")
    }

    @MainActor
    func testEditingRejectsUnsafeAddressesAndMergesDuplicates() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = BookmarkStore(defaults: defaults)
        store.toggle(title: "First", url: URL(string: "https://one.example")!)
        store.toggle(title: "Second", url: URL(string: "https://two.example")!)
        let item = store.items[0]
        for address in ["javascript:alert(1)", "file:///private/file", "https://", "not a website"] {
            XCTAssertFalse(store.update(item, title: "Wrong", address: address))
        }
        XCTAssertEqual(store.items[0], item)
        XCTAssertTrue(store.update(item, title: "", address: "https://one.example"))
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].id, item.id)
        XCTAssertEqual(store.items[0].title, "one.example")
    }
}
