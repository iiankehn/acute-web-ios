import XCTest
import WebKit
@testable import AcuteWeb

final class PermissionBrokerTests: XCTestCase {
    @MainActor
    func testReplacementDeniesOldRequestAndStaleApprovalCannotGrantNewRequest() {
        let broker = PermissionBroker()
        let tab = UUID()
        var oldDecisions: [WKPermissionDecision] = []
        var newDecisions: [WKPermissionDecision] = []
        broker.request(tabID: tab, host: "old.example", kind: .camera) { oldDecisions.append($0) }
        let oldID = broker.pendingRequest!.id
        broker.request(tabID: tab, host: "new.example", kind: .microphone) { newDecisions.append($0) }
        XCTAssertEqual(oldDecisions, [.deny])
        broker.resolve(.grant, requestID: oldID)
        XCTAssertTrue(newDecisions.isEmpty)
        broker.resolve(.grant, requestID: broker.pendingRequest!.id)
        XCTAssertEqual(newDecisions, [.grant])
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
