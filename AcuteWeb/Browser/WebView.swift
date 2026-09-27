import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let tab: BrowserTab
    let downloadCenter: DownloadCenter
    let permissionBroker: PermissionBroker
    let sitePrivacy: SitePrivacyStore

    func makeCoordinator() -> Coordinator {
        Coordinator(downloadCenter: downloadCenter, permissionBroker: permissionBroker, sitePrivacy: sitePrivacy)
    }

    func makeUIView(context: Context) -> WKWebView {
        tab.webView.navigationDelegate = context.coordinator
        tab.webView.uiDelegate = context.coordinator
        return tab.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let downloadCenter: DownloadCenter
        let permissionBroker: PermissionBroker
        let sitePrivacy: SitePrivacyStore

        init(downloadCenter: DownloadCenter, permissionBroker: PermissionBroker, sitePrivacy: SitePrivacyStore) {
            self.downloadCenter = downloadCenter
            self.permissionBroker = permissionBroker
            self.sitePrivacy = sitePrivacy
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
            decisionHandler(["http", "https", "about", "data", "blob"].contains(scheme) ? .allow : .cancel, preferences)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let request = navigationAction.request.url {
                webView.load(URLRequest(url: request))
            }
            return nil
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
