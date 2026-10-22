import Foundation
import UIKit
import WebKit

enum ConnectionSecurity: Equatable {
    case none, secure, mixedContent, insecure

    var symbol: String {
        switch self {
        case .none: return "globe"
        case .secure: return "lock.fill"
        case .mixedContent: return "lock.slash"
        case .insecure: return "exclamationmark.triangle.fill"
        }
    }

    var summary: String {
        switch self {
        case .none: return "No website loaded"
        case .secure: return "Secure connection"
        case .mixedContent: return "Some content on this page isn’t secure"
        case .insecure: return "Not secure"
        }
    }
}

@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable {
    let id = UUID()
    let isPrivate: Bool
    let webView: WKWebView
    var lastRequestedURL: URL?
    var navigationCoordinator: WebView.Coordinator?
    /// A restored tab waits to load until it is first selected.
    var awaitsRestoredLoad = false
    /// The website process ended while the tab was in the background; reload when it is selected.
    var reloadsWhenSelected = false
    /// Opened by a website with window.open, so window.close may close it.
    var wasOpenedByWebsite = false

    @Published var title = "New Tab"
    @Published var url: URL?
    @Published var estimatedProgress = 0.0
    @Published var isLoading = false
    @Published var hasRenderedPage = false
    @Published var navigationError: String?
    @Published var navigationFailure: NavigationFailure?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var snapshot: UIImage?
    @Published var usesDesktopSite = false
    @Published private(set) var pageZoom = 1.0
    @Published private(set) var hasOnlySecureContent = false

    private var observations: [NSKeyValueObservation] = []
    private let refreshControl = UIRefreshControl()

    var connectionSecurity: ConnectionSecurity {
        switch url?.scheme?.lowercased() {
        case "https": return hasOnlySecureContent ? .secure : .mixedContent
        case "http": return .insecure
        default: return .none
        }
    }

    /// Creates a tab. A website-opened window must use the configuration WebKit provides.
    init(isPrivate: Bool = false, dataStore: WKWebsiteDataStore? = nil, configuration provided: WKWebViewConfiguration? = nil) {
        self.isPrivate = isPrivate

        let configuration = provided ?? WKWebViewConfiguration()
        if provided == nil {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains(UITestNavigationFixture.launchArgument) {
                configuration.setURLSchemeHandler(UITestNavigationFixture(), forURLScheme: UITestNavigationFixture.scheme)
            }
#endif
            configuration.websiteDataStore = dataStore ?? (isPrivate ? .nonPersistent() : .default())
            configuration.preferences.isFraudulentWebsiteWarningEnabled = true
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            configuration.mediaTypesRequiringUserActionForPlayback = .all
            configuration.allowsInlineMediaPlayback = true
        }

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.isInspectable = false

        super.init()
        refreshControl.addTarget(self, action: #selector(refreshFromPull), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
        observeWebView()
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in
                    guard let self else { return }
                    if let title = view.title, !title.isEmpty { self.title = title }
                    else if !self.awaitsRestoredLoad { self.title = "New Tab" }
                }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.url = view.url }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.estimatedProgress = view.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in
                    self?.isLoading = view.isLoading
                    if !view.isLoading { self?.refreshControl.endRefreshing() }
                }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoForward = view.canGoForward }
            },
            webView.observe(\.hasOnlySecureContent, options: [.initial, .new]) { [weak self] view, _ in
                Task { @MainActor in self?.hasOnlySecureContent = view.hasOnlySecureContent }
            }
        ]
    }

    @objc private func refreshFromPull() {
        if navigationError != nil, let url = lastRequestedURL {
            showFailure(nil)
            webView.load(URLRequest(url: url))
        } else if webView.url != nil {
            webView.reload()
        } else {
            refreshControl.endRefreshing()
        }
    }

    func showFailure(_ failure: NavigationFailure?) {
        navigationFailure = failure
        navigationError = failure?.message
    }

    /// Loads a restored or reclaimed tab the first time it is shown.
    func loadDeferredContentIfNeeded() {
        guard awaitsRestoredLoad || reloadsWhenSelected, let url = lastRequestedURL else { return }
        awaitsRestoredLoad = false
        reloadsWhenSelected = false
        showFailure(nil)
        webView.load(URLRequest(url: url))
    }

    func captureSnapshot() {
        guard !isPrivate, url != nil else { return }
        webView.takeSnapshot(with: nil) { [weak self] image, _ in
            Task { @MainActor in self?.snapshot = image }
        }
    }

    func setPageZoom(_ value: Double) {
        guard value.isFinite else { return }
        pageZoom = min(max(value, 0.5), 2.0)
        webView.pageZoom = pageZoom
    }

    func toggleDesktopSite() {
        usesDesktopSite.toggle()
        webView.configuration.defaultWebpagePreferences.preferredContentMode = usesDesktopSite ? .desktop : .mobile
        webView.reload()
    }
}
