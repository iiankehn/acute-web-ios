import Foundation

enum ScriptDialogKind { case alert, confirm, prompt, externalLink }
enum ScriptDialogAnswer { case accept(String), cancel }

final class ScriptDialogRequest: Identifiable {
    let id = UUID()
    let tabID: UUID
    let host: String
    let message: String
    let kind: ScriptDialogKind
    let defaultText: String
    fileprivate let completion: (ScriptDialogAnswer) -> Void

    init(tabID: UUID, host: String, message: String, kind: ScriptDialogKind,
         defaultText: String, completion: @escaping (ScriptDialogAnswer) -> Void) {
        self.tabID = tabID
        self.host = host
        self.message = message
        self.kind = kind
        self.defaultText = defaultText
        self.completion = completion
    }
}

@MainActor
final class ScriptDialogBroker: ObservableObject {
    @Published private(set) var pendingRequest: ScriptDialogRequest?
    private var queue: [ScriptDialogRequest] = []
    private var isAdvancing = false

    func request(tabID: UUID, host: String, message: String, kind: ScriptDialogKind,
                 defaultText: String = "", completion: @escaping (ScriptDialogAnswer) -> Void) {
        let request = ScriptDialogRequest(tabID: tabID, host: host, message: message,
                                          kind: kind, defaultText: defaultText, completion: completion)
        if pendingRequest == nil && !isAdvancing { pendingRequest = request }
        else { queue.append(request) }
    }

    func resolve(_ answer: ScriptDialogAnswer, requestID: UUID? = nil) {
        guard let request = pendingRequest, requestID == nil || requestID == request.id else { return }
        pendingRequest = nil
        isAdvancing = true
        request.completion(answer)
        // Let the native alert finish dismissing before presenting a queued website dialog.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            isAdvancing = false
            if pendingRequest == nil, !queue.isEmpty { pendingRequest = queue.removeFirst() }
        }
    }

    func cancel(tabID: UUID) {
        let cancelled = queue.filter { $0.tabID == tabID }
        queue.removeAll { $0.tabID == tabID }
        if pendingRequest?.tabID == tabID { resolve(.cancel) }
        cancelled.forEach { $0.completion(.cancel) }
    }
}
