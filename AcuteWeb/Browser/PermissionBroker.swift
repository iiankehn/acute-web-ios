import Foundation
import WebKit

enum SitePermissionKind {
    case camera
    case microphone
    case cameraAndMicrophone

    var title: String {
        switch self {
        case .camera: return "camera"
        case .microphone: return "microphone"
        case .cameraAndMicrophone: return "camera and microphone"
        }
    }
}

final class SitePermissionRequest: Identifiable {
    let id = UUID()
    let tabID: UUID
    let host: String
    let kind: SitePermissionKind
    fileprivate let completion: (WKPermissionDecision) -> Void

    init(tabID: UUID, host: String, kind: SitePermissionKind, completion: @escaping (WKPermissionDecision) -> Void) {
        self.tabID = tabID
        self.host = host
        self.kind = kind
        self.completion = completion
    }
}

@MainActor
final class PermissionBroker: ObservableObject {
    @Published private(set) var pendingRequest: SitePermissionRequest?

    func request(tabID: UUID, host: String, kind: SitePermissionKind, completion: @escaping (WKPermissionDecision) -> Void) {
        let replaced = pendingRequest
        pendingRequest = SitePermissionRequest(tabID: tabID, host: host, kind: kind, completion: completion)
        replaced?.completion(.deny)
    }

    func resolve(_ decision: WKPermissionDecision, requestID: UUID? = nil) {
        guard let request = pendingRequest, requestID == nil || request.id == requestID else { return }
        pendingRequest = nil
        request.completion(decision)
    }

    func cancel(tabID: UUID) {
        if pendingRequest?.tabID == tabID { resolve(.deny) }
    }
}
