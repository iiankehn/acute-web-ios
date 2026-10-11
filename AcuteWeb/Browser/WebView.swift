import SwiftUI
import WebKit
import UIKit

struct WebView: UIViewRepresentable {
    let tab: BrowserTab
    let downloadCenter: DownloadCenter
    let permissionBroker: PermissionBroker
    let sitePrivacy: SitePrivacyStore
    let openLink: (URLRequest, Bool) -> Void
    let scriptDialogs: ScriptDialogBroker
    let canPresentDialogs: () -> Bool
    let prepareNavigation: (WKWebView, URL?, @escaping () -> Void) -> Void

    func makeCoordinator() -> Coordinator {
        tab.navigationCoordinator ?? Coordinator(tab: tab, downloadCenter: downloadCenter, permissionBroker: permissionBroker, sitePrivacy: sitePrivacy, openLink: openLink, scriptDialogs: scriptDialogs, canPresentDialogs: canPresentDialogs, prepareNavigation: prepareNavigation)
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
        let downloadCenter: DownloadCenter
        let permissionBroker: PermissionBroker
        let sitePrivacy: SitePrivacyStore
        let openLink: (URLRequest, Bool) -> Void
        let scriptDialogs: ScriptDialogBroker
        let canPresentDialogs: () -> Bool
        let prepareNavigation: (WKWebView, URL?, @escaping () -> Void) -> Void

        init(tab: BrowserTab, downloadCenter: DownloadCenter, permissionBroker: PermissionBroker, sitePrivacy: SitePrivacyStore, openLink: @escaping (URLRequest, Bool) -> Void, scriptDialogs: ScriptDialogBroker, canPresentDialogs: @escaping () -> Bool, prepareNavigation: @escaping (WKWebView, URL?, @escaping () -> Void) -> Void) {
            self.tab = tab
            self.downloadCenter = downloadCenter
            self.permissionBroker = permissionBroker
            self.sitePrivacy = sitePrivacy
            self.openLink = openLink
            self.scriptDialogs = scriptDialogs
            self.canPresentDialogs = canPresentDialogs
            self.prepareNavigation = prepareNavigation
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if let tab {
                scriptDialogs.cancel(tabID: tab.id)
                permissionBroker.cancel(tabID: tab.id)
            }
            tab?.navigationError = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showNavigationError(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showNavigationError(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard let tab else { return }
            scriptDialogs.cancel(tabID: tab.id)
            permissionBroker.cancel(tabID: tab.id)
            tab.isLoading = false
            tab.estimatedProgress = 0
            tab.snapshot = nil
            tab.lastRequestedURL = webView.url ?? tab.lastRequestedURL
            if tab.lastRequestedURL != nil {
                tab.navigationError = "The website stopped responding. Try loading it again."
            }
        }

        private func showNavigationError(_ error: Error) {
            let failure = error as NSError
            guard !(failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled) else { return }
            tab?.navigationError = error.localizedDescription
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            preferences: WKWebpagePreferences,
            decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
        ) {
            preferences.allowsContentJavaScript = sitePrivacy.policy(for: navigationAction.request.url?.host).allowsJavaScript
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download, preferences)
                return
            }
            guard let scheme = navigationAction.request.url?.scheme?.lowercased() else {
                decisionHandler(.cancel, preferences)
                return
            }
            guard ["http", "https", "about", "data", "blob"].contains(scheme) else {
                decisionHandler(.cancel, preferences)
                if let url = navigationAction.request.url {
                    requestExternalLink(url, navigationType: navigationAction.navigationType,
                                        isMainFrame: navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true)
                }
                return
            }
            if navigationAction.targetFrame?.isMainFrame == true {
                tab?.lastRequestedURL = navigationAction.request.url
                prepareNavigation(webView, navigationAction.request.url) {
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
                  let tab, canPresentDialogs() else { return false }
            let tabID = tab.id
            let warning = tab.isPrivate ? "\n\nPrivate browsing protection does not extend to other apps." : ""
            scriptDialogs.request(tabID: tabID, host: "Open Another App?",
                                 message: "This link will open outside Acute Web:\n\(url.absoluteString)\(warning)", kind: .externalLink) { [weak self] answer in
                guard let self, case .accept = answer, self.tab?.id == tabID, self.canPresentDialogs() else { return }
                if let open { open(url); return }
                UIApplication.shared.open(url, options: [:]) { [weak self] success in
                    guard let self, !success, self.tab?.id == tabID, self.canPresentDialogs() else { return }
                    self.scriptDialogs.request(tabID: tabID, host: "Unable to Open Link",
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
            if navigationAction.targetFrame == nil {
                openLink(navigationAction.request, tab?.isPrivate == true)
            }
            return nil
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
                    self.openLink(URLRequest(url: url), self.tab?.isPrivate == true)
                }
                let openPrivate = UIAction(title: "Open in New Private Tab", image: UIImage(systemName: "hand.raised.fill")) { [weak self] _ in
                    self?.openLink(URLRequest(url: url), true)
                }
                return UIMenu(children: [open, openPrivate] + suggestedActions)
            })
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            downloadCenter.register(download)
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            downloadCenter.register(download)
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            guard let tab, canPresentDialogs() else { completionHandler(); return }
            scriptDialogs.request(tabID: tab.id, host: frame.request.url?.host ?? "Website", message: message, kind: .alert) { _ in
                completionHandler()
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            guard let tab, canPresentDialogs() else { completionHandler(false); return }
            scriptDialogs.request(tabID: tab.id, host: frame.request.url?.host ?? "Website", message: message, kind: .confirm) { answer in
                if case .accept = answer { completionHandler(true) } else { completionHandler(false) }
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            guard let tab, canPresentDialogs() else { completionHandler(nil); return }
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
            if sitePrivacy.policy(for: origin.host).blocksMediaCapture {
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
            guard let tab, canPresentDialogs() else { decisionHandler(.deny); return }
            permissionBroker.request(tabID: tab.id, host: origin.host, kind: kind, completion: decisionHandler)
        }
    }
}
