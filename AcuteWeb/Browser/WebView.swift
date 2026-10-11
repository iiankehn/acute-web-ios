import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let tab: BrowserTab
    let downloadCenter: DownloadCenter
    let permissionBroker: PermissionBroker
    let sitePrivacy: SitePrivacyStore
    let openLink: (URLRequest, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        tab.navigationCoordinator ?? Coordinator(tab: tab, downloadCenter: downloadCenter, permissionBroker: permissionBroker, sitePrivacy: sitePrivacy, openLink: openLink)
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

        init(tab: BrowserTab, downloadCenter: DownloadCenter, permissionBroker: PermissionBroker, sitePrivacy: SitePrivacyStore, openLink: @escaping (URLRequest, Bool) -> Void) {
            self.tab = tab
            self.downloadCenter = downloadCenter
            self.permissionBroker = permissionBroker
            self.sitePrivacy = sitePrivacy
            self.openLink = openLink
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            tab?.navigationError = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showNavigationError(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showNavigationError(error)
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
            if navigationAction.targetFrame?.isMainFrame == true {
                tab?.lastRequestedURL = navigationAction.request.url
            }
            preferences.allowsContentJavaScript = sitePrivacy.policy(for: navigationAction.request.url?.host).allowsJavaScript
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download, preferences)
                return
            }
            guard let scheme = navigationAction.request.url?.scheme?.lowercased() else {
                decisionHandler(.cancel, preferences)
                return
            }
            decisionHandler(["http", "https", "about", "data", "blob"].contains(scheme) ? .allow : .cancel, preferences)
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
            permissionBroker.request(host: origin.host, kind: kind, completion: decisionHandler)
        }
    }
}
