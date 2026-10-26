import XCTest

/// End-to-end checks of navigation in the running app: a deep link, a result travelling back from
/// a picker, and dismissal reporting no result.
final class NavigationFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// `demoapp://issues/<id>` from another tab switches to the Issues tab, resets its stack, and
    /// pushes the issue.
    @MainActor
    func testDeepLinkOpensIssueInIssuesTab() throws {
        app.tabBars.buttons["Screen D"].tap()

        app.open(try XCTUnwrap(URL(string: "demoapp://issues/00000000-0000-0000-0000-000000000002")))
        confirmOpenInAppIfAsked()

        XCTAssertTrue(app.navigationBars["#931"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Issues"].isSelected)

        // Opened by the tab's list, as its own child: back lands on that list.
        app.navigationBars["#931"].buttons["BackButton"].tap()
        XCTAssertTrue(app.navigationBars["Issues"].waitForExistence(timeout: 5))
    }

    /// Deleting a deep-linked issue is handled by the list it opened in, as for a tapped row. Uses
    /// seed issue #904, which no other test opens; it stays deleted until the app is reinstalled.
    @MainActor
    func testDeleteDeepLinkedIssueReturnsToList() throws {
        app.tabBars.buttons["Screen D"].tap()
        app.open(try XCTUnwrap(URL(string: "demoapp://issues/00000000-0000-0000-0000-000000000003")))
        confirmOpenInAppIfAsked()
        XCTAssertTrue(app.navigationBars["#904"].waitForExistence(timeout: 5))

        app.buttons["more_actions_button"].tap()
        app.buttons["Delete"].tap()
        app.alerts.buttons["Delete"].tap()

        XCTAssertTrue(app.navigationBars["Issues"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Electrical panel labeling'")).firstMatch.exists)
    }

    /// `demoapp://screenC` from another tab: Screen C is a tab root, so the link selects its tab.
    @MainActor
    func testDeepLinkOpensScreenC() throws {
        app.tabBars.buttons["Screen B"].tap()

        app.open(try XCTUnwrap(URL(string: "demoapp://screenC")))
        confirmOpenInAppIfAsked()

        XCTAssertTrue(app.staticTexts["Screen C · UIKit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Screen C"].isSelected)
    }

    /// `demoapp://issues?action=screenCContext` from another tab: lands on the Issues tab, whose root
    /// list receives the action and pushes Screen C; Send fills that same list's header.
    @MainActor
    func testDeepLinkRunsScreenCContext() throws {
        app.tabBars.buttons["Screen B"].tap()

        // Through the system, like `simctl openurl`: `XCUIApplication.open(_:)` drops the query.
        XCUIDevice.shared.system.open(try XCTUnwrap(URL(string: "demoapp://issues?action=screenCContext")))
        confirmOpenInAppIfAsked()

        XCTAssertTrue(app.staticTexts["I have been pushed from the issues list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Issues"].isSelected)
        let field = app.textFields["Message to caller"]
        field.tap()
        field.typeText("From a link")
        app.buttons["Send"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Screen C said “From a link”"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["Issues"].exists)   // the tab's root list, not a second one
    }

    /// Screen B presents the Issues picker with `.selectSingle(.issues)`; the picked issue comes back
    /// as `.selectedEntity` and the sheet closes itself.
    @MainActor
    func testPickerReturnsIssueToScreenB() {
        app.tabBars.buttons["Screen B"].tap()
        app.buttons["Link an issue"].tap()

        XCTAssertTrue(app.navigationBars["Pick an issue"].waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Plumbing riser leak'")).firstMatch.tap()

        XCTAssertTrue(app.buttons["Link another issue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Pick an issue"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Plumbing riser leak'")).firstMatch.exists)
    }

    /// Swiping the picker away reports `.dismissed`: Screen B stays unlinked.
    @MainActor
    func testDismissingPickerLinksNothing() {
        app.tabBars.buttons["Screen B"].tap()
        app.buttons["Link an issue"].tap()

        let pickerBar = app.navigationBars["Pick an issue"]
        XCTAssertTrue(pickerBar.waitForExistence(timeout: 5))
        pickerBar.swipeDown(velocity: .fast)

        XCTAssertTrue(app.buttons["Link an issue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Link another issue"].exists)
    }

    /// Issue details hosts the RefPicker: Add Reference presents the Issues picker, and the pick
    /// shows up under "Related issues".
    @MainActor
    func testAddReferenceToIssue() {
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Commissioning'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["#928"].waitForExistence(timeout: 5))

        let add = app.buttons["Add Reference"]
        for _ in 0..<4 where !add.isHittable { app.swipeUp() }
        add.tap()

        XCTAssertTrue(app.navigationBars["Pick an issue"].waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Plumbing riser leak'")).firstMatch.tap()

        XCTAssertTrue(app.navigationBars["#928"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Plumbing riser leak'")).firstMatch.waitForExistence(timeout: 5))
    }

    /// The Issues list pushes Screen C with `.compose`; each Send comes back as a typed output, Screen C
    /// stays up, and after popping back the Context chip shows the last text.
    @MainActor
    func testScreenCContextReportsBackToIssues() {
        app.buttons["Push Screen C with context"].tap()

        XCTAssertTrue(app.staticTexts["I have been pushed from the issues list"].waitForExistence(timeout: 5))
        let field = app.textFields["Message to caller"]
        field.tap()
        field.typeText("Hello")
        app.buttons["Send"].tap()
        XCTAssertTrue(app.textFields["Message to caller"].exists)   // still on Screen C

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Screen C said “Hello”"].waitForExistence(timeout: 5))
    }

    // MARK: - Issues list → detail through the navigator

    private func openCommissioningIssue() {
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Commissioning'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["#928"].waitForExistence(timeout: 5))
    }

    private var issuesListBar: XCUIElement { app.navigationBars["Issues"] }

    /// The button labelled `label` above the tab bar — screens reuse tab names for their links.
    private func inScreenButton(_ label: String) -> XCUIElement {
        let tabBarTop = app.tabBars.firstMatch.frame.minY
        let candidates = app.buttons.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex
        return candidates.first { $0.frame.maxY < tabBarTop } ?? candidates[0]
    }

    /// Back button: the detail leaves, the list's detail state clears, and the same row opens again.
    @MainActor
    func testDetailBackButtonThenReopen() {
        openCommissioningIssue()

        app.navigationBars["#928"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(issuesListBar.waitForExistence(timeout: 5))

        openCommissioningIssue()
    }

    /// Interactive swipe-back clears the list's detail state the same way.
    @MainActor
    func testDetailSwipeBackThenReopen() {
        openCommissioningIssue()

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(issuesListBar.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["#928"].exists)

        openCommissioningIssue()
    }

    /// Delete in the detail is handled by the list (its parent): the issue goes away and the
    /// navigator entry is removed, landing back on the list. Deletes an issue it creates itself, so
    /// the persisted seed issues other tests open stay put.
    @MainActor
    func testDeleteFromDetailReturnsToList() {
        let newRows = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'New'"))
        let before = newRows.count
        app.buttons["add_issue_button"].tap()
        XCTAssertTrue(app.navigationBars["New"].waitForExistence(timeout: 5))

        app.buttons["more_actions_button"].tap()
        app.buttons["Delete"].tap()
        app.alerts.buttons["Delete"].tap()

        XCTAssertTrue(issuesListBar.waitForExistence(timeout: 5))
        XCTAssertEqual(newRows.count, before)
    }

    /// A deep link landing on the Issues tab while a detail is open resets the stack — the detail
    /// included — and its list can open details again afterwards.
    @MainActor
    func testDeepLinkResetsOpenDetail() throws {
        openCommissioningIssue()

        XCUIDevice.shared.system.open(try XCTUnwrap(URL(string: "demoapp://issues?action=screenCContext")))
        confirmOpenInAppIfAsked()

        XCTAssertTrue(app.staticTexts["I have been pushed from the issues list"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(issuesListBar.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["#928"].exists)

        openCommissioningIssue()
    }

    /// From a detail pushed by its list, a cross-module push (Screen C) stacks on top, and going
    /// back returns to the same detail.
    @MainActor
    func testCrossModulePushFromDetail() {
        openCommissioningIssue()

        inScreenButton("Screen C").tap()   // the detail's push link, not the "Screen C" tab
        XCTAssertTrue(app.navigationBars["Screen C"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Issues"].isSelected)

        app.navigationBars["Screen C"].buttons["BackButton"].tap()
        XCTAssertTrue(app.navigationBars["#928"].waitForExistence(timeout: 5))
    }

    /// Screen B pushes B2 through the navigator; back returns to Screen B, and B2 opens again.
    @MainActor
    func testScreenB2BackThenReopen() {
        app.tabBars.buttons["Screen B"].tap()

        app.buttons["Push to Screen B2"].tap()
        XCTAssertTrue(app.navigationBars["Screen B2"].waitForExistence(timeout: 5))
        app.navigationBars["Screen B2"].buttons["BackButton"].tap()
        XCTAssertTrue(app.navigationBars["Screen B"].waitForExistence(timeout: 5))

        app.buttons["Push to Screen B2"].tap()
        XCTAssertTrue(app.navigationBars["Screen B2"].waitForExistence(timeout: 5))
    }

    /// From B2, a cross-module push (Issues) stacks on top, and back returns to B2.
    @MainActor
    func testCrossModulePushFromScreenB2() {
        app.tabBars.buttons["Screen B"].tap()
        app.buttons["Push to Screen B2"].tap()
        XCTAssertTrue(app.navigationBars["Screen B2"].waitForExistence(timeout: 5))

        inScreenButton("Issues").tap()
        XCTAssertTrue(app.navigationBars["Issues"].waitForExistence(timeout: 5))
        app.navigationBars["Issues"].buttons["BackButton"].tap()
        XCTAssertTrue(app.navigationBars["Screen B2"].waitForExistence(timeout: 5))
    }

    // MARK: Issues (scope): the list owns its detail's state and scopes the detail's store

    private var scopeListBar: XCUIElement { app.navigationBars["Issues (scope)"] }

    /// Opens #950 from the scope tab. #950 is opened by no other test.
    private func openPaintIssueInScopeList() {
        app.tabBars.buttons["Issues (scope)"].tap()
        XCTAssertTrue(scopeListBar.waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Paint touch-up in lobby'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["#950"].waitForExistence(timeout: 5))
    }

    /// Back clears the list's detail state (`.detail(.dismiss)`), and the same row opens again.
    @MainActor
    func testScopeDetailBackThenReopen() {
        openPaintIssueInScopeList()

        app.navigationBars["#950"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(scopeListBar.waitForExistence(timeout: 5))

        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Paint touch-up in lobby'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["#950"].waitForExistence(timeout: 5))
    }

    /// Interactive swipe-back clears the state the same way.
    @MainActor
    func testScopeDetailSwipeBackThenReopen() {
        openPaintIssueInScopeList()

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(scopeListBar.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["#950"].exists)

        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Paint touch-up in lobby'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["#950"].waitForExistence(timeout: 5))
    }

    /// Delete is the parent's: it clears the state, removes the issue and pops through the navigator.
    /// Deletes an issue it creates itself, so the seed issues stay put.
    @MainActor
    func testScopeDeleteFromDetailReturnsToList() {
        app.tabBars.buttons["Issues (scope)"].tap()
        XCTAssertTrue(scopeListBar.waitForExistence(timeout: 5))
        let newRows = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'New'"))
        let before = newRows.count
        app.buttons["add_scope_issue_button"].tap()
        XCTAssertTrue(app.navigationBars["New"].waitForExistence(timeout: 5))

        app.buttons["more_actions_button"].tap()
        app.buttons["Delete"].tap()
        app.alerts.buttons["Delete"].tap()

        XCTAssertTrue(scopeListBar.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["New"].exists)
        XCTAssertEqual(newRows.count, before)
    }

    /// `demoapp://issues-scope/<id>` lands on the scope tab and opens the issue as the list's own
    /// child: back lands on that list. Uses #955, which no other test opens.
    @MainActor
    func testScopeDeepLinkOpensIssueInList() throws {
        app.tabBars.buttons["Screen D"].tap()
        app.open(try XCTUnwrap(URL(string: "demoapp://issues-scope/00000000-0000-0000-0000-000000000006")))
        confirmOpenInAppIfAsked()

        XCTAssertTrue(app.navigationBars["#955"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Issues (scope)"].isSelected)
        app.navigationBars["#955"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(scopeListBar.waitForExistence(timeout: 5))
    }

    /// The first time a URL targets the app, iOS may ask for confirmation in SpringBoard.
    private func confirmOpenInAppIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["Open"]
        if open.waitForExistence(timeout: 3) {
            open.tap()
        }
    }
}
