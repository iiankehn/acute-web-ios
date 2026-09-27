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
    let host: String
    let kind: SitePermissionKind
    fileprivate let completion: (WKPermissionDecision) -> Void

    init(host: String, kind: SitePermissionKind, completion: @escaping (WKPermissionDecision) -> Void) {
        self.host = host
        self.kind = kind
        self.completion = completion
    }
}

@MainActor
final class PermissionBroker: ObservableObject {
    @Published var pendingRequest: SitePermissionRequest?

    func request(host: String, kind: SitePermissionKind, completion: @escaping (WKPermissionDecision) -> Void) {
        if let pendingRequest { pendingRequest.completion(.deny) }
        pendingRequest = SitePermissionRequest(host: host, kind: kind, completion: completion)
    }

    func resolve(_ decision: WKPermissionDecision) {
        pendingRequest?.completion(decision)
        pendingRequest = nil
    }
}
