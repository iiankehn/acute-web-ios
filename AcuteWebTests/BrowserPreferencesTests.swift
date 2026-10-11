import XCTest
import Combine
@testable import AcuteWeb

final class BrowserPreferencesTests: XCTestCase {
    @MainActor
    func testStartPageChangesPublishAndPersistAcrossRelaunch() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = BrowserPreferences(defaults: defaults)
        XCTAssertTrue(preferences.showsStartFavorites)
        var updates: [Bool] = []
        let observation = preferences.$showsStartFavorites.sink { updates.append($0) }
        preferences.showsStartFavorites = false
        preferences.showsStartBookmarks = false
        preferences.showsStartRecentSites = false
        XCTAssertEqual(updates, [true, false])
        let restored = BrowserPreferences(defaults: defaults)
        XCTAssertFalse(restored.showsStartFavorites)
        XCTAssertFalse(restored.showsStartBookmarks)
        XCTAssertFalse(restored.showsStartRecentSites)
        preferences.showsStartFavorites = true
        XCTAssertTrue(BrowserPreferences(defaults: defaults).showsStartFavorites)
        withExtendedLifetime(observation) {}
    }
}
