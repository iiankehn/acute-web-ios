import XCTest
@testable import AcuteWeb

final class ScriptDialogBrokerTests: XCTestCase {
    @MainActor
    func testDialogQueueReturnsPromptTextAndIgnoresAnOldDismissal() {
        let broker = ScriptDialogBroker()
        let tab = UUID()
        var firstCalls = 0
        var response: String?
        broker.request(tabID: tab, host: "one.example", message: "Confirm?", kind: .confirm) { _ in firstCalls += 1 }
        let firstID = broker.pendingRequest!.id
        broker.request(tabID: tab, host: "two.example", message: "Name?", kind: .prompt, defaultText: "Initial") { answer in
            if case .accept(let text) = answer { response = text }
        }
        broker.resolve(.accept(""), requestID: firstID)
        XCTAssertEqual(firstCalls, 1)
        let advanced = expectation(for: NSPredicate { _, _ in broker.pendingRequest?.host == "two.example" }, evaluatedWith: nil)
        // The broker waits 350 ms before showing the next dialog; slow runners need far longer than that.
        wait(for: [advanced], timeout: 10)
        XCTAssertEqual(broker.pendingRequest?.defaultText, "Initial")
        broker.resolve(.cancel, requestID: firstID)
        XCTAssertEqual(broker.pendingRequest?.host, "two.example")
        broker.resolve(.accept("Acute"), requestID: broker.pendingRequest!.id)
        XCTAssertEqual(response, "Acute")
        XCTAssertNil(broker.pendingRequest)
    }

    @MainActor
    func testClosingATabCancelsItsActiveAndQueuedDialogsExactlyOnce() {
        let broker = ScriptDialogBroker()
        let closedTab = UUID()
        let otherTab = UUID()
        var cancellations = 0
        let completion: (ScriptDialogAnswer) -> Void = { answer in
            if case .cancel = answer { cancellations += 1 }
        }
        broker.request(tabID: closedTab, host: "one.example", message: "First", kind: .confirm, completion: completion)
        broker.request(tabID: closedTab, host: "one.example", message: "Second", kind: .prompt, completion: completion)
        broker.request(tabID: otherTab, host: "two.example", message: "Other", kind: .alert) { _ in }
        broker.cancel(tabID: closedTab)
        XCTAssertEqual(cancellations, 2)
        let advanced = expectation(for: NSPredicate { _, _ in broker.pendingRequest?.tabID == otherTab }, evaluatedWith: nil)
        // The broker waits 350 ms before showing the next dialog; slow runners need far longer than that.
        wait(for: [advanced], timeout: 10)
        XCTAssertEqual(broker.pendingRequest?.tabID, otherTab)
        broker.cancel(tabID: closedTab)
        XCTAssertEqual(cancellations, 2)
    }
}
