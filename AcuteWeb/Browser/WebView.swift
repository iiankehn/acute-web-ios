import SwiftUI
import WebKit
import UIKit

struct WebView: UIViewRepresentable {
    let tab: BrowserTab
    let browser: BrowserStore

    func makeCoordinator() -> Coordinator {
        tab.navigationCoordinator ?? Coordinator(tab: tab, browser: browser)
    }

    func makeUIView(context: Context) -> WKWebView {
        tab.navigationCoordinator = context.coordinator
        tab.webView.navigationDelegate = context.coordinator
        tab.webView.uiDelegate = context.coordinator
        return tab.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var tab: BrowserTab?
        weak var browser: BrowserStore?

        init(tab: BrowserTab, browser: BrowserStore) {
            self.tab = tab
            self.browser = browser
        }

        private var scriptDialogs: ScriptDialogBroker? { browser?.scriptDialogs }

        private func canPresentDialogs() -> Bool {
            guard let tab, let browser else { return false }
            return browser.canPresentDialogs(for: tab)
        }

        private func policy(for host: String?) -> SitePrivacyPolicy {
            browser?.sitePrivacy.policy(for: host, isPrivate: tab?.isPrivate == true) ?? SitePrivacyPolicy()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if let tab {
                scriptDialogs?.pageChanged(tabID: tab.id)
                browser?.permissionBroker.cancel(tabID: tab.id)
            }
            tab?.showFailure(nil)
            tab?.hasRenderedPage = false
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab?.hasRenderedPage = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showNavigationError(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showNavigationError(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard let tab else { return }
            scriptDialogs?.cancel(tabID: tab.id)
            browser?.permissionBroker.cancel(tabID: tab.id)
            tab.isLoading = false
            tab.estimatedProgress = 0
            tab.snapshot = nil
            tab.lastRequestedURL = webView.url ?? tab.lastRequestedURL
            guard tab.lastRequestedURL != nil else { return }
            tab.showFailure(NavigationFailure(message: "The website stopped responding. Try loading it again."))
            // iOS reclaims background pages under memory pressure; reload those quietly when they are shown again.
            if browser?.selectedTabID != tab.id { tab.reloadsWhenSelected = true }
        }

        private func showNavigationError(_ error: Error) {
            guard !NavigationFailure.isIgnorable(error) else { return }
            tab?.showFailure(NavigationFailure(error))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            preferences: WKWebpagePreferences,
            decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
        ) {
            preferences.allowsContentJavaScript = policy(for: navigationAction.request.url?.host).allowsJavaScript
            let isMainFrame = navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true
            if navigationAction.shouldPerformDownload {
                // Embedded frames may not start downloads unless the person activated a link.
                decisionHandler(isMainFrame || navigationAction.navigationType == .linkActivated ? .download : .cancel, preferences)
                return
            }
            guard let scheme = navigationAction.request.url?.scheme?.lowercased() else {
                decisionHandler(.cancel, preferences)
                return
            }
            guard ["http", "https", "about", "data", "blob"].contains(scheme) else {
#if DEBUG
                if scheme == UITestNavigationFixture.scheme,
                   ProcessInfo.processInfo.arguments.contains(UITestNavigationFixture.launchArgument) {
                    tab?.lastRequestedURL = navigationAction.request.url
                    decisionHandler(.allow, preferences)
                    return
                }
#endif
                decisionHandler(.cancel, preferences)
                if let url = navigationAction.request.url {
                    requestExternalLink(url, navigationType: navigationAction.navigationType, isMainFrame: isMainFrame)
                }
                return
            }
            if navigationAction.targetFrame?.isMainFrame == true, let browser {
                tab?.lastRequestedURL = navigationAction.request.url
                browser.prepareNavigation(webView, url: navigationAction.request.url) {
                    decisionHandler(.allow, preferences)
                }
            } else {
                decisionHandler(.allow, preferences)
            }
        }

        @MainActor
        @discardableResult
        func requestExternalLink(_ url: URL, navigationType: WKNavigationType, isMainFrame: Bool,
                                 open: ((URL) -> Void)? = nil) -> Bool {
            guard ExternalLinkPolicy.allows(url, navigationType: navigationType, isMainFrame: isMainFrame),
                  let tab, let scriptDialogs, canPresentDialogs() else { return false }
            let tabID = tab.id
            let warning = tab.isPrivate ? "\n\nPrivate browsing protection does not extend to other apps." : ""
            scriptDialogs.request(tabID: tabID, host: "Open Another App?",
                                  message: "This link will open outside Acute Web:\n\(url.absoluteString)\(warning)", kind: .externalLink) { [weak self] answer in
                guard let self, case .accept = answer, self.tab?.id == tabID, self.canPresentDialogs() else { return }
                if let open { open(url); return }
                UIApplication.shared.open(url, options: [:]) { [weak self] success in
                    guard let self, !success, self.tab?.id == tabID, self.canPresentDialogs() else { return }
                    self.scriptDialogs?.request(tabID: tabID, host: "Unable to Open Link",
                                                message: "No available app could open this link.", kind: .alert) { _ in }
                }
            }
            return true
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil, let tab, let browser else { return nil }
            let scheme = navigationAction.request.url?.scheme?.lowercased() ?? "about"
            guard ["http", "https", "about"].contains(scheme) else { return nil }
            // Returning a web view built from WebKit's configuration keeps window.opener and the sign-in session.
            return browser.openWebsiteWindow(configuration: configuration, request: navigationAction.request, isPrivate: tab.isPrivate)
        }

        func webViewDidClose(_ webView: WKWebView) {
            guard let tab, tab.wasOpenedByWebsite else { return }
            browser?.close(tab)
        }

        func webView(
            _ webView: WKWebView,
            contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
            completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
        ) {
            guard let url = elementInfo.linkURL, let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
                completionHandler(UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
                    UIMenu(children: suggestedActions)
                })
                return
            }
            completionHandler(UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
                let open = UIAction(title: "Open in New Tab", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
                    guard let self else { return }
                    self.browser?.openInNewTab(URLRequest(url: url), isPrivate: self.tab?.isPrivate == true)
                }
                let openPrivate = UIAction(title: "Open in New Private Tab", image: UIImage(systemName: "hand.raised.fill")) { [weak self] _ in
                    self?.browser?.openInNewTab(URLRequest(url: url), isPrivate: true)
                }
                return UIMenu(children: [open, openPrivate] + suggestedActions)
            })
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                // Hidden frames and ads cannot save files; only the page the person is viewing can.
                decisionHandler(navigationResponse.isForMainFrame ? .download : .cancel)
            }
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            browser?.downloadCenter.register(download)
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            browser?.downloadCenter.register(download)
        }

        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            let space = challenge.protectionSpace
            let methods = [NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodNTLM]
            guard methods.contains(space.authenticationMethod), challenge.previousFailureCount < 3,
                  let tab, let scriptDialogs, canPresentDialogs() else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            let insecure = space.receivesCredentialSecurely ? "" : "\n\nThis connection isn’t secure. Your password will be visible to others on the network."
            let retry = challenge.previousFailureCount > 0 ? "\n\nThe user name or password was incorrect." : ""
            let persistence: URLCredential.Persistence = tab.isPrivate ? .none : .forSession
            scriptDialogs.request(tabID: tab.id, host: "Sign In to \(space.host)",
                                  message: "This website requires a user name and password.\(retry)\(insecure)",
                                  kind: .credentials, defaultText: challenge.proposedCredential?.user ?? "") { answer in
                if case .credentials(let user, let password) = answer {
                    completionHandler(.useCredential, URLCredential(user: user, password: password, persistence: persistence))
                } else {
                    completionHandler(.performDefaultHandling, nil)
                }
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            guard let tab, let scriptDialogs, canPresentDialogs() else { completionHandler(); return }
            scriptDialogs.request(tabID: tab.id, host: frame.request.url?.host ?? "Website", message: message, kind: .alert) { _ in
                completionHandler()
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            guard let tab, let scriptDialogs, canPresentDialogs() else { completionHandler(false); return }
            scriptDialogs.request(tabID: tab.id, host: frame.request.url?.host ?? "Website", message: message, kind: .confirm) { answer in
                if case .accept = answer { completionHandler(true) } else { completionHandler(false) }
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            guard let tab, let scriptDialogs, canPresentDialogs() else { completionHandler(nil); return }
            scriptDialogs.request(tabID: tab.id, host: frame.request.url?.host ?? "Website", message: prompt,
                                  kind: .prompt, defaultText: defaultText ?? "") { answer in
                if case .accept(let text) = answer { completionHandler(text) } else { completionHandler(nil) }
            }
        }

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            let sitePolicy = policy(for: origin.host)
            if sitePolicy.mediaCapture == .block {
                decisionHandler(.deny)
                return
            }
            let kind: SitePermissionKind
            switch type {
            case .camera:
                kind = .camera
            case .microphone:
                kind = .microphone
            case .cameraAndMicrophone:
                kind = .cameraAndMicrophone
            @unknown default:
                decisionHandler(.deny)
                return
            }
            // Even an always-allowed site may only capture while its tab is on screen.
            guard let tab, let browser, canPresentDialogs() else { decisionHandler(.deny); return }
            if sitePolicy.mediaCapture == .allow {
                decisionHandler(.grant)
                return
            }
            let host = origin.host
            let isPrivate = tab.isPrivate
            browser.permissionBroker.requestDecision(tabID: tab.id, host: host, kind: kind) { [weak browser] decision in
                if decision == .alwaysAllow {
                    browser?.sitePrivacy.update(host: host, isPrivate: isPrivate) { $0.mediaCapture = .allow }
                }
                decisionHandler(decision == .deny ? .deny : .grant)
            }
        }
    }
}
