import XCTest
import Combine
@testable import AcuteWeb

final class BrowserPreferencesTests: XCTestCase {
    @MainActor
    func testBrowsingLayoutDefaultsAndChangesPersist() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("unknown", forKey: "phoneControlsPosition")
        let preferences = BrowserPreferences(defaults: defaults)
        XCTAssertEqual(preferences.phoneControlsPosition, .top)
        XCTAssertTrue(preferences.condensesPhoneControls)
        XCTAssertTrue(preferences.showsCompactPageTitle)
        preferences.phoneControlsPosition = .bottom
        preferences.condensesPhoneControls = false
        preferences.showsCompactPageTitle = false
        let restored = BrowserPreferences(defaults: defaults)
        XCTAssertEqual(restored.phoneControlsPosition, .bottom)
        XCTAssertFalse(restored.condensesPhoneControls)
        XCTAssertFalse(restored.showsCompactPageTitle)
    }

    @MainActor
    func testStringLaunchOverridesUseBooleanSemantics() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("NO", forKey: "restoresTabs")
        defaults.set("NO", forKey: "blocksTrackers")
        defaults.set("NO", forKey: "showsStartFavorites")
        defaults.set("YES", forKey: "savesHistory")
        let preferences = BrowserPreferences(defaults: defaults)
        XCTAssertFalse(preferences.restoresTabs)
        XCTAssertFalse(preferences.blocksTrackers)
        XCTAssertFalse(preferences.showsStartFavorites)
        XCTAssertTrue(preferences.savesHistory)
    }

    @MainActor
    func testUnsetPreferencesRetainPrivacyDefaults() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = BrowserPreferences(defaults: defaults)
        XCTAssertTrue(preferences.restoresTabs)
        XCTAssertTrue(preferences.blocksTrackers)
        XCTAssertFalse(preferences.savesHistory)
    }

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
