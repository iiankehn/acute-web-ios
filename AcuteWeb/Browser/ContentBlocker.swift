import WebKit

@MainActor
final class ContentBlocker {
    private var compiledRuleList: WKContentRuleList?
    private var isCompiling = false
    private var pendingWebViews: [WKWebView] = []

    func apply(enabled: Bool, to webView: WKWebView) {
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        guard enabled else { return }

        if let compiledRuleList {
            controller.add(compiledRuleList)
            return
        }

        pendingWebViews.append(webView)
        guard !isCompiling else { return }
        isCompiling = true

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AcutePrivacyRules-v2",
            encodedContentRuleList: Self.rules
        ) { [weak self] ruleList, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isCompiling = false
                self.compiledRuleList = ruleList
                guard let ruleList else {
                    self.pendingWebViews.removeAll()
                    return
                }
                for pendingWebView in self.pendingWebViews {
                    pendingWebView.configuration.userContentController.add(ruleList)
                }
                self.pendingWebViews.removeAll()
            }
        }
    }

    private static let rules = #"""
    [
      {
        "trigger": {
          "url-filter": ".*",
          "if-domain": [
            "*doubleclick.net",
            "*googlesyndication.com",
            "*google-analytics.com",
            "*googletagmanager.com",
            "*connect.facebook.net",
            "*ads-twitter.com",
            "*scorecardresearch.com",
            "*adnxs.com",
            "*amazon-adsystem.com",
            "*taboola.com",
            "*outbrain.com",
            "*hotjar.com",
            "*segment.io",
            "*segment.com",
            "*mixpanel.com",
            "*amplitude.com",
            "*branch.io",
            "*appsflyer.com",
            "*criteo.com",
            "*criteo.net",
            "*quantserve.com",
            "*rubiconproject.com",
            "*pubmatic.com"
          ],
          "resource-type": ["script", "image", "style-sheet", "raw"]
        },
        "action": { "type": "block" }
      }
    ]
    """#
}
