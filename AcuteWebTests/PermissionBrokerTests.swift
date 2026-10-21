import XCTest
import WebKit
@testable import AcuteWeb

final class PermissionBrokerTests: XCTestCase {
    @MainActor
    func testSecondRequestWaitsAndStaleApprovalCannotGrantTheNextRequest() {
        let broker = PermissionBroker()
        let tab = UUID()
        var firstDecisions: [WKPermissionDecision] = []
        var secondDecisions: [WKPermissionDecision] = []
        broker.request(tabID: tab, host: "first.example", kind: .camera) { firstDecisions.append($0) }
        let firstID = broker.pendingRequest!.id
        broker.request(tabID: tab, host: "second.example", kind: .microphone) { secondDecisions.append($0) }
        XCTAssertTrue(firstDecisions.isEmpty, "A second prompt must not silently deny the first")
        XCTAssertEqual(broker.pendingRequest?.host, "first.example")
        broker.resolve(.deny, requestID: firstID)
        XCTAssertEqual(firstDecisions, [.deny])
        XCTAssertEqual(broker.pendingRequest?.host, "second.example")
        broker.resolve(.grant, requestID: firstID)
        XCTAssertTrue(secondDecisions.isEmpty)
        broker.resolve(.grant, requestID: broker.pendingRequest!.id)
        XCTAssertEqual(secondDecisions, [.grant])
        XCTAssertNil(broker.pendingRequest)
    }

    @MainActor
    func testAlwaysAllowIsReportedAndClosingATabDeniesItsQueuedRequests() {
        let broker = PermissionBroker()
        let closing = UUID()
        let other = UUID()
        var decisions: [SitePermissionDecision] = []
        var queued: [WKPermissionDecision] = []
        broker.requestDecision(tabID: other, host: "other.example", kind: .camera) { decisions.append($0) }
        broker.request(tabID: closing, host: "closing.example", kind: .microphone) { queued.append($0) }
        broker.cancel(tabID: closing)
        XCTAssertEqual(queued, [.deny])
        broker.decide(.alwaysAllow, requestID: broker.pendingRequest!.id)
        XCTAssertEqual(decisions, [.alwaysAllow])
        XCTAssertNil(broker.pendingRequest)
    }

    @MainActor
    func testCancellationOnlyDeniesRequestsOwnedByTheClosedTabOnce() {
        let broker = PermissionBroker()
        let tab = UUID()
        var decisions: [WKPermissionDecision] = []
        broker.request(tabID: tab, host: "example.com", kind: .cameraAndMicrophone) { decisions.append($0) }
        broker.cancel(tabID: UUID())
        XCTAssertNotNil(broker.pendingRequest)
        broker.cancel(tabID: tab)
        broker.cancel(tabID: tab)
        XCTAssertEqual(decisions, [.deny])
        XCTAssertNil(broker.pendingRequest)
    }
}
