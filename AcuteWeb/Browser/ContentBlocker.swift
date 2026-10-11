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
            forIdentifier: "AcutePrivacyRules-v3", encodedContentRuleList: Self.rules
        ) { [weak self] ruleList, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isCompiling = false
                self.compiledRuleList = ruleList
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

    static var rules: String {
        let entries: [[String: Any]] = trackerDomains.map { domain in
            ["trigger": ["url-filter": resourceFilter(for: domain),
                         "resource-type": ["script", "image", "style-sheet", "raw"]],
             "action": ["type": "block"]]
        }
        return String(data: try! JSONSerialization.data(withJSONObject: entries), encoding: .utf8)!
    }
}
