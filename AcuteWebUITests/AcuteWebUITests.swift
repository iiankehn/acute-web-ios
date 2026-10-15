import XCTest

final class AcuteWebUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-savesHistory", "NO", "-restoresTabs", "NO", "-showsStartFavorites", "YES",
                               "-phoneControlsPosition", "top", "-condensesPhoneControls", "YES", "-showsCompactPageTitle", "YES"]
        app.launch()
    }

    func testFailedPageCanEditAddressAndReturnToStartPage() {
        app.terminate()
        app.launchArguments += ["-acuteUITestPageError"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Unable to Load Page"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["failedPageHost"].label, "acute-error.invalid")
        XCTAssertTrue(app.buttons["Try Again"].isHittable)
        app.buttons["editFailedAddress"].tap()
        let clear = app.buttons["clearAddress"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        let address = app.textFields["addressField"]
        address.typeText("replacement query")
        XCTAssertEqual(address.value as? String, "replacement query")
        scrollTo(app.buttons["failedPageStartPage"])
        app.buttons["failedPageStartPage"].tap()
        XCTAssertTrue(app.staticTexts["The web, in focus."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Unable to Load Page"].exists)
        XCTAssertEqual(app.textFields["addressField"].value as? String, "Search or enter address")
    }

    func testLaunchShowsNativeStartPage() {
        XCTAssertTrue(app.staticTexts["Acute Web"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["The web, in focus."].exists)
        XCTAssertTrue(app.textFields["addressField"].exists)
    }

    func testPhoneLayoutOptionsMoveControlsAndDisableCondensation() {
        app.terminate()
        app.launchArguments += ["-acuteUITestRenderedPage"]
        app.launch()
        XCTAssertTrue(app.buttons["condensedAddress"].waitForExistence(timeout: 15))
        openMoreMenu()
        app.buttons["Settings"].tap()
        let bottom = app.buttons["phoneLayout_bottom"]
        scrollTo(bottom)
        bottom.tap()
        let condensation = app.switches["Condense controls after loading"]
        scrollTo(condensation)
        setSwitch(condensation, enabled: false)
        app.buttons["Done"].tap()
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(address.frame.midY, app.frame.height / 2)
        XCTAssertFalse(app.buttons["condensedAddress"].exists)
        openMoreMenu()
        app.buttons["Settings"].tap()
        let top = app.buttons["phoneLayout_top"]
        scrollTo(top)
        top.tap()
        scrollTo(condensation)
        setSwitch(condensation, enabled: true)
        app.buttons["Done"].tap()
        let condensed = app.buttons["condensedAddress"]
        XCTAssertTrue(condensed.waitForExistence(timeout: 5))
        XCTAssertLessThan(condensed.frame.midY, app.frame.height / 2)
    }

    func testRenderedPhonePageCondensesAndCanExpandControls() {
        app.terminate()
        app.launchArguments += ["-acuteUITestRenderedPage"]
        app.launch()
        let condensed = app.buttons["condensedAddress"]
        XCTAssertTrue(condensed.waitForExistence(timeout: 15))
        XCTAssertFalse(app.textFields["addressField"].exists)
        XCTAssertTrue(app.buttons["pageLoadControl"].isHittable)
        XCTAssertTrue(app.buttons["Tabs"].isHittable)
        XCTAssertTrue(app.buttons["More"].isHittable)
        condensed.tap()
        XCTAssertTrue(app.textFields["addressField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Back"].exists)
        finishAddressEditing()
        XCTAssertTrue(condensed.waitForExistence(timeout: 5))
        chooseMoreAction("New Tab", category: "Tab Management")
        XCTAssertTrue(app.textFields["addressField"].waitForExistence(timeout: 5))
        XCTAssertFalse(condensed.exists)
    }

    func testUnsupportedTypedAddressShowsClearFeedback() {
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        address.tap()
        address.typeText("javascript:alert(1)\n")
        XCTAssertTrue(app.alerts["Unable to Open Address"].waitForExistence(timeout: 5))
        app.alerts["Unable to Open Address"].buttons["OK"].tap()
        XCTAssertTrue(app.staticTexts["The web, in focus."].exists)
    }

    func testClearAddressKeepsCurrentPageAndAllowsReplacementInput() {
        app.terminate()
        app.launchArguments += ["-acuteUITestRenderedPage"]
        app.launch()
        let condensed = app.buttons["condensedAddress"]
        XCTAssertTrue(condensed.waitForExistence(timeout: 15))
        XCTAssertTrue((condensed.value as? String)?.contains("Acute navigation fixture") == true)
        condensed.tap()
        let clear = app.buttons["clearAddress"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pageLoadControl"].isHittable)
        clear.tap()
        let address = app.textFields["addressField"]
        XCTAssertEqual(address.value as? String, "Search or enter address")
        XCTAssertTrue(app.buttons["pageLoadControl"].isHittable)
        address.typeText("replacement query")
        XCTAssertEqual(address.value as? String, "replacement query")
        clear.tap()
        finishAddressEditing()
        XCTAssertTrue(condensed.waitForExistence(timeout: 5))
        XCTAssertTrue((condensed.value as? String)?.contains("acute-fixture.invalid") == true)
    }

    func testFindFromCondensedControlsReturnsToCondensedPage() {
        app.terminate()
        app.launchArguments += ["-acuteUITestRenderedPage"]
        app.launch()
        let condensed = app.buttons["condensedAddress"]
        XCTAssertTrue(condensed.waitForExistence(timeout: 15))
        openMoreMenu()
        app.buttons["Page Tools"].tap()
        app.buttons["Find on Page"].tap()
        let field = app.textFields["findField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["addressField"].exists)
        field.tap()
        field.typeText("Loaded")
        let status = app.staticTexts["findStatus"]
        let found = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Match found"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [found], timeout: 10), .completed)
        app.buttons["Close Find on Page"].tap()
        XCTAssertTrue(condensed.waitForExistence(timeout: 5))
        XCTAssertFalse(field.exists)
    }

    func testCompactToolbarKeepsAddressAndMenuUsableAfterRotation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(address.frame.width, 80)
        XCTAssertTrue(app.buttons["More"].isHittable)
        XCTAssertTrue(app.buttons["Tabs"].isHittable)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5))
        XCTAssertTrue(address.isHittable)
        XCTAssertGreaterThan(address.frame.width, 80)
        XCTAssertTrue(app.buttons["More"].isHittable)
        openMoreMenu()
        app.buttons["Tab Management"].tap()
        XCTAssertTrue(app.buttons["New Private Tab"].waitForExistence(timeout: 5))
    }

    func testTabSwitcherCreatesPrivateTabsAndClosesLastTab() {
        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 5))
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selectTab_'"))
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.firstMatch.value as? String, "Selected tab")

        app.buttons["New Tab Options"].tap()
        app.buttons["New Private Tab"].tap()
        XCTAssertTrue(app.staticTexts["Private browsing"].waitForExistence(timeout: 5))
        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 5))
        XCTAssertEqual(cards.count, 2)

        let closeButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'closeTab_'"))
        closeButtons.firstMatch.tap()
        XCTAssertEqual(cards.count, 1)
        closeButtons.firstMatch.tap()
        XCTAssertEqual(cards.count, 1)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["The web, in focus."].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["addressField"].value as? String, "Search or enter address")
    }

    func testTabFiltersPreserveSelectedPrivateTab() {
        chooseMoreAction("New Private Tab", category: "Tab Management")
        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 5))
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selectTab_'"))
        let filter = app.segmentedControls["tabScopePicker"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.buttons["Private"].tap()
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.firstMatch.value as? String, "Selected tab")
        filter.buttons["Regular"].tap()
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.firstMatch.value as? String, "Regular tab")
        filter.buttons["All"].tap()
        XCTAssertEqual(cards.count, 2)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Private browsing"].waitForExistence(timeout: 5))
    }

    func testTabSearchClosesOnlyVisibleCardAndKeepsHiddenSelection() {
        app.terminate()
        app.launchArguments += ["-acuteUITestRenderedPage"]
        app.launch()
        XCTAssertTrue(app.buttons["condensedAddress"].waitForExistence(timeout: 15))
        chooseMoreAction("New Private Tab", category: "Tab Management")
        app.buttons["Tabs"].tap()
        let search = app.searchFields["Search tabs"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("acute-fixture.invalid")
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selectTab_'"))
        XCTAssertTrue(app.staticTexts["1 of 2 open"].waitForExistence(timeout: 5))
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.firstMatch.value as? String, "Regular tab")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'closeTab_'"))
            .firstMatch.tap()
        XCTAssertTrue(app.staticTexts["0 of 1 open"].waitForExistence(timeout: 5))
        XCTAssertEqual(cards.count, 0)
        let clearSearch = app.buttons["clearTabSearch"]
        XCTAssertTrue(clearSearch.waitForExistence(timeout: 5))
        scrollTo(clearSearch)
        clearSearch.tap()
        XCTAssertTrue(app.staticTexts["1 of 1 open"].waitForExistence(timeout: 5))
        XCTAssertEqual(cards.firstMatch.value as? String, "Selected tab")
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(app.staticTexts["Private browsing"].waitForExistence(timeout: 5))
    }

    func testPrivacySettingsDefaultToNoHistory() {
        openMoreMenu()
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let telemetry = app.descendants(matching: .any).matching(identifier: "telemetryStatus").firstMatch
        scrollTo(telemetry)
        XCTAssertEqual(telemetry.label, "Acute telemetry")
        XCTAssertEqual(telemetry.value as? String, "None")
        let historySwitch = app.switches["Save browsing history"]
        XCTAssertTrue(historySwitch.exists)
        XCTAssertEqual(historySwitch.value as? String, "0")
    }

    func testPrivateTabUsesPrivateStartPage() {
        chooseMoreAction("New Private Tab", category: "Tab Management")

        XCTAssertTrue(app.staticTexts["Private browsing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Downloaded files remain on this device'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Favorites"].exists)
        XCTAssertFalse(app.staticTexts["Bookmarks"].exists)
    }

    func testLibraryExposesBookmarksAndHistory() {
        chooseMoreAction("Bookmarks and History", category: "Saved Content")

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Bookmarks"].exists)
        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No History"].waitForExistence(timeout: 5))
    }

    func testPrivacyPolicyIsReadableInsideSettings() {
        openMoreMenu()
        app.buttons["Settings"].tap()
        let policy = app.buttons["privacyPolicyLink"]
        scrollTo(policy)
        policy.tap()
        XCTAssertTrue(app.navigationBars["Privacy Policy"].waitForExistence(timeout: 5))
        let text = app.staticTexts["privacyPolicyText"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("No support report is sent automatically"))
        app.navigationBars["Privacy Policy"].buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    func testLibrarySearchRecoveryRestoresSheetNavigation() {
        chooseMoreAction("Bookmarks and History", category: "Saved Content")
        let search = app.searchFields["Search titles or addresses"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("no matching saved page 48291")
        let clear = app.buttons["clearLibrarySearch"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].isHittable)
        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No History"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5))
    }

    func testDownloadsSearchRecoveryRestoresSheetNavigation() {
        chooseMoreAction("Downloads", category: "Saved Content")
        let search = app.searchFields["Search downloads"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("no matching download 48291")
        let clear = app.buttons["clearDownloadsSearch"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].isHittable)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5))
    }

    func testBookmarkQuickEditValidatesAddressAndPreservesCancelledChanges() {
        app.terminate()
        app.launchArguments += ["-acuteUITestRenderedPage"]
        app.launch()
        XCTAssertTrue(app.buttons["condensedAddress"].waitForExistence(timeout: 15))
        openMoreMenu()
        app.buttons["Saved Content"].tap()
        // The test may run against an existing bookmark from an earlier run.
        if app.buttons["Add Bookmark"].exists {
            app.buttons["Add Bookmark"].tap()
            chooseMoreAction("Bookmarks and History", category: "Saved Content")
        } else {
            app.buttons["Bookmarks and History"].tap()
        }
        let edit = app.buttons["Edit Acute navigation fixture"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.navigationBars["Edit Bookmark"].waitForExistence(timeout: 5))
        app.buttons["clearBookmarkAddress"].tap()
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        XCTAssertTrue(app.staticTexts["Enter an HTTP or HTTPS website address."].exists)
        let address = app.textFields["bookmarkAddress"]
        address.typeText("https://acute-fixture.invalid/")
        XCTAssertTrue(app.buttons["Save"].isEnabled)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        edit.tap()
        app.buttons["clearBookmarkAddress"].tap()
        address.typeText("https://cancelled-edit.invalid/")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertEqual(address.value as? String, "https://acute-fixture.invalid/")
        app.buttons["Cancel"].tap()
        app.buttons["Done"].tap()
    }

    func testSessionRecoveryExplainsPrivateTabExclusion() {
        openMoreMenu()
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let restoreSwitch = app.switches["Restore regular tabs"]
        scrollTo(restoreSwitch)
        XCTAssertEqual(restoreSwitch.value as? String, "0")
        let explanation = app.staticTexts["sessionRecoveryExplanation"]
        scrollTo(explanation)
        XCTAssertTrue(explanation.label.contains("Private tabs are never saved or restored"))
    }

    func testStartPageCustomizationUpdatesImmediately() {
        openMoreMenu()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let favorites = app.switches["Show favorites"]
        scrollTo(favorites)
        setSwitch(favorites, enabled: false)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.textFields["startSearchField"].waitForExistence(timeout: 5))
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["Favorites"])
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)

        openMoreMenu()
        app.buttons["Settings"].tap()
        scrollTo(favorites)
        setSwitch(favorites, enabled: true)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Favorites"].waitForExistence(timeout: 5))
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    func testBulkPrivateTabClosingRequiresConfirmation() {
        chooseMoreAction("New Private Tab", category: "Tab Management")
        app.buttons["Tabs"].tap()
        XCTAssertTrue(app.navigationBars["Tabs"].waitForExistence(timeout: 5))
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'selectTab_'"))
        XCTAssertEqual(cards.count, 2)
        app.buttons["Tab Actions"].tap()
        app.buttons["Close Private Tabs"].tap()
        let confirmation = app.alerts["Close Private Tabs"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.buttons["Cancel"].exists)
        confirmation.buttons["Cancel"].tap()
        XCTAssertEqual(cards.count, 2)
        app.buttons["Tab Actions"].tap()
        app.buttons["Close Private Tabs"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Close Private Tabs"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in cards.count == 1 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["The web, in focus."].waitForExistence(timeout: 5))
    }

    func testClearingWebsiteDataRequiresConfirmationAndCanBeCancelled() {
        openMoreMenu()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let clear = app.buttons["Clear Regular Website Data"]
        scrollTo(clear)
        clear.tap()
        let confirmation = app.alerts["Clear Regular Website Data?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.buttons["Clear Website Data"].exists)
        confirmation.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Regular website data cleared"].exists)
        XCTAssertTrue(clear.exists)
    }

    private func setSwitch(_ element: XCUIElement, enabled: Bool) {
        let expected = enabled ? "1" : "0"
        if element.value as? String != expected {
            // Tap the trailing switch control rather than the center of its labeled Form row.
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    private func openMoreMenu() {
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
    }

    private func chooseMoreAction(_ title: String, category: String) {
        openMoreMenu()
        let group = app.buttons[category]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        group.tap()
        let action = app.buttons[title]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
    }

    private func finishAddressEditing() {
        chooseMoreAction("Done Editing", category: "Page Tools")
    }

    func testCapsuleRowKeepsHistoryNavigationVisible() {
        app.terminate()
        app.launchArguments += ["-acuteUITestHistoryPage"]
        app.launch()
        let address = app.buttons["condensedAddress"]
        XCTAssertTrue(address.waitForExistence(timeout: 15))
        let back = app.buttons["Back"]
        XCTAssertTrue(back.exists)
        XCTAssertFalse(back.isEnabled)
        XCTAssertFalse(app.buttons["Forward"].exists)
        XCTAssertEqual(back.frame.midY, address.frame.midY, accuracy: 2)
        XCTAssertEqual(app.buttons["More"].frame.midY, address.frame.midY, accuracy: 2)
        let next = app.webViews.links["Next fixture page"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(app.webViews.staticTexts["Second fixture page"].waitForExistence(timeout: 5))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in back.isEnabled }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        XCTAssertTrue(back.isHittable)
        back.tap()
        let forward = app.buttons["Forward"]
        XCTAssertTrue(forward.waitForExistence(timeout: 5))
        XCTAssertTrue(forward.isHittable)
        XCTAssertEqual(forward.frame.midY, app.buttons["More"].frame.midY, accuracy: 2)
        forward.tap()
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !forward.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)
    }

    func testCapsuleRowSwitchesBetweenRegularAndPrivateTabs() {
        chooseMoreAction("New Private Tab", category: "Tab Management")
        XCTAssertTrue(app.staticTexts["Private browsing"].waitForExistence(timeout: 5))
        let capsules = app.scrollViews["navigationTabCapsules"]
        let otherTab = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'toolbarSelect_'"))
        capsules.swipeRight()
        XCTAssertTrue(otherTab.firstMatch.isHittable)
        otherTab.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["The web, in focus."].waitForExistence(timeout: 5))
        capsules.swipeLeft()
        XCTAssertTrue(otherTab.firstMatch.isHittable)
        otherTab.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Private browsing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Back"].exists)
        XCTAssertTrue(app.buttons["More"].isHittable)
    }

}
