import Foundation
import UIKit
import WebKit

@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable {
    let id = UUID()
    let isPrivate: Bool
    let webView: WKWebView

    @Published var title = "New Tab"
    @Published var url: URL?
    @Published var estimatedProgress = 0.0
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var snapshot: UIImage?
    @Published var usesDesktopSite = false

    private var observations: [NSKeyValueObservation] = []

    init(isPrivate: Bool = false) {
        self.isPrivate = isPrivate

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.isInspectable = false

        super.init()
        observeWebView()
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.title = view.title?.isEmpty == false ? view.title! : "New Tab" }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.url = view.url }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.estimatedProgress = view.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.isLoading = view.isLoading }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoForward = view.canGoForward }
            }
        ]
    }

    func captureSnapshot() {
        guard url != nil else { return }
        webView.takeSnapshot(with: nil) { [weak self] image, _ in
            Task { @MainActor in self?.snapshot = image }
        }
    }

    func toggleDesktopSite() {
        usesDesktopSite.toggle()
        webView.configuration.defaultWebpagePreferences.preferredContentMode = usesDesktopSite ? .desktop : .mobile
        webView.reload()
    }
}
