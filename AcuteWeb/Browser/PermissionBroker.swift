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

enum SitePermissionDecision {
    case deny, allowOnce, alwaysAllow
}

final class SitePermissionRequest: Identifiable {
    let id = UUID()
    let tabID: UUID
    let host: String
    let kind: SitePermissionKind
    fileprivate let completion: (SitePermissionDecision) -> Void

    init(tabID: UUID, host: String, kind: SitePermissionKind, completion: @escaping (SitePermissionDecision) -> Void) {
        self.tabID = tabID
        self.host = host
        self.kind = kind
        self.completion = completion
    }
}

@MainActor
final class PermissionBroker: ObservableObject {
    @Published private(set) var pendingRequest: SitePermissionRequest?
    private var queue: [SitePermissionRequest] = []

    func request(tabID: UUID, host: String, kind: SitePermissionKind, completion: @escaping (WKPermissionDecision) -> Void) {
        requestDecision(tabID: tabID, host: host, kind: kind) { completion($0 == .deny ? .deny : .grant) }
    }

    /// Requests wait their turn so a second prompt never silently denies the first.
    func requestDecision(tabID: UUID, host: String, kind: SitePermissionKind,
                         completion: @escaping (SitePermissionDecision) -> Void) {
        let request = SitePermissionRequest(tabID: tabID, host: host, kind: kind, completion: completion)
        if pendingRequest == nil { pendingRequest = request }
        else { queue.append(request) }
    }

    func resolve(_ decision: WKPermissionDecision, requestID: UUID? = nil) {
        decide(decision == .grant ? .allowOnce : .deny, requestID: requestID)
    }

    func decide(_ decision: SitePermissionDecision, requestID: UUID? = nil) {
        guard let request = pendingRequest, requestID == nil || request.id == requestID else { return }
        pendingRequest = queue.isEmpty ? nil : queue.removeFirst()
        request.completion(decision)
    }

    func cancel(tabID: UUID) {
        let cancelled = queue.filter { $0.tabID == tabID }
        queue.removeAll { $0.tabID == tabID }
        cancelled.forEach { $0.completion(.deny) }
        if pendingRequest?.tabID == tabID { decide(.deny) }
    }
}
