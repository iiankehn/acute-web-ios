import Foundation
import WebKit

@MainActor
final class ContentBlocker {
    private var compiledRuleList: WKContentRuleList?
    private var isCompiling = false
    private struct Pending {
        weak var webView: WKWebView?
        var completions: [() -> Void]
    }
    private var pendingWebViews: [ObjectIdentifier: Pending] = [:]
    /// True when WebKit could not compile the rules, so pages are loading without tracker blocking.
    private(set) var compilationFailed = false
    var statusChanged: ((Bool) -> Void)?

    func apply(enabled: Bool, to webView: WKWebView, completion: (() -> Void)? = nil) {
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        let key = ObjectIdentifier(webView)
        guard enabled else {
            let pending = pendingWebViews.removeValue(forKey: key)
            pending?.completions.forEach { $0() }
            completion?()
            return
        }
        if let compiledRuleList {
            controller.add(compiledRuleList)
            completion?()
            return
        }
        var pending = pendingWebViews[key] ?? Pending(webView: webView, completions: [])
        if let completion { pending.completions.append(completion) }
        pendingWebViews[key] = pending
        guard !isCompiling else { return }
        isCompiling = true
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AcutePrivacyRules-v4", encodedContentRuleList: Self.rules
        ) { [weak self] ruleList, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isCompiling = false
                self.compiledRuleList = ruleList
                // A failed compile is retried on the next navigation; report it so the interface stays truthful.
                if self.compilationFailed != (ruleList == nil) {
                    self.compilationFailed = ruleList == nil
                    self.statusChanged?(self.compilationFailed)
                }
                let pending = self.pendingWebViews
                self.pendingWebViews.removeAll()
                for entry in pending.values {
                    if let ruleList, let webView = entry.webView {
                        webView.configuration.userContentController.add(ruleList)
                    }
                    entry.completions.forEach { $0() }
                }
            }
        }
    }

    static let trackerDomains = [
        "doubleclick.net", "googlesyndication.com", "google-analytics.com", "googletagmanager.com",
        "connect.facebook.net", "ads-twitter.com", "scorecardresearch.com", "adnxs.com",
        "amazon-adsystem.com", "taboola.com", "outbrain.com", "hotjar.com", "segment.io", "segment.com",
        "mixpanel.com", "amplitude.com", "branch.io", "appsflyer.com", "criteo.com", "criteo.net",
        "quantserve.com", "rubiconproject.com", "pubmatic.com"
    ]

    static func resourceFilter(for domain: String) -> String {
        "^https?://([a-z0-9-]+\\.)*" + domain.replacingOccurrences(of: ".", with: "\\.") + "(:[0-9]+)?/"
    }

    static let blockedResourceTypes = ["script", "image", "style-sheet", "raw", "media", "font", "ping"]

    static var rules: String {
        let entries: [[String: Any]] = trackerDomains.flatMap { domain -> [[String: Any]] in
            let filter = resourceFilter(for: domain)
            return [
                ["trigger": ["url-filter": filter, "resource-type": blockedResourceTypes],
                 "action": ["type": "block"]],
                // Embedded tracker frames are blocked; visiting one of these sites directly still works.
                ["trigger": ["url-filter": filter, "resource-type": ["document"], "load-context": ["child-frame"]],
                 "action": ["type": "block"]]
            ]
        }
        return String(data: try! JSONSerialization.data(withJSONObject: entries), encoding: .utf8)!
    }
}
