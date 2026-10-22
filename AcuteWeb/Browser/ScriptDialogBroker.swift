import Foundation

enum ScriptDialogKind { case alert, confirm, prompt, externalLink, download, credentials }
enum ScriptDialogAnswer { case accept(String), credentials(user: String, password: String), cancel }

final class ScriptDialogRequest: Identifiable {
    let id = UUID()
    let tabID: UUID
    let host: String
    let message: String
    let kind: ScriptDialogKind
    let defaultText: String
    /// Set once a page has already shown a dialog, so the person can stop further ones.
    fileprivate(set) var offersSuppression = false
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
    /// Further website dialogs from a tab are cancelled once this many are waiting.
    static let queueLimitPerTab = 3

    @Published private(set) var pendingRequest: ScriptDialogRequest?
    private var queue: [ScriptDialogRequest] = []
    private var isAdvancing = false
    private var shownCounts: [UUID: Int] = [:]
    private var suppressedTabs: Set<UUID> = []

    func request(tabID: UUID, host: String, message: String, kind: ScriptDialogKind,
                 defaultText: String = "", completion: @escaping (ScriptDialogAnswer) -> Void) {
        let request = ScriptDialogRequest(tabID: tabID, host: host, message: message,
                                          kind: kind, defaultText: defaultText, completion: completion)
        let waiting = queue.filter { $0.tabID == tabID }.count + (pendingRequest?.tabID == tabID ? 1 : 0)
        guard !suppressedTabs.contains(tabID), waiting < Self.queueLimitPerTab else {
            completion(.cancel)
            return
        }
        shownCounts[tabID, default: 0] += 1
        request.offersSuppression = shownCounts[tabID, default: 0] > 1
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

    /// Cancels the current dialog and every later one from the same page until it navigates.
    func suppress(requestID: UUID) {
        guard let request = pendingRequest, request.id == requestID else { return }
        suppressedTabs.insert(request.tabID)
        cancel(tabID: request.tabID)
    }

    func isSuppressed(tabID: UUID) -> Bool {
        suppressedTabs.contains(tabID)
    }

    /// A new page starts with a clean dialog history.
    func pageChanged(tabID: UUID) {
        cancel(tabID: tabID)
        shownCounts.removeValue(forKey: tabID)
        suppressedTabs.remove(tabID)
    }

    func cancel(tabID: UUID) {
        let cancelled = queue.filter { $0.tabID == tabID }
        queue.removeAll { $0.tabID == tabID }
        if pendingRequest?.tabID == tabID { resolve(.cancel) }
        cancelled.forEach { $0.completion(.cancel) }
    }
}
