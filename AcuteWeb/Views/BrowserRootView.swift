import SwiftUI

struct BrowserRootView: View {
    @EnvironmentObject private var browser: BrowserStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Any private tab can appear in the tab row, sidebar or tab overview, so all of them keep the app-switcher cover on.
    private var coversForPrivacy: Bool {
        scenePhase != .active && browser.tabs.contains { $0.isPrivate }
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
                NavigationSplitView {
                    TabSidebar()
                        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 340)
                } detail: {
                    browserContent
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                browserContent
            }
        }
        .sheet(isPresented: $browser.showsTabs) {
            NavigationStack { TabGrid() }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $browser.showsSettings) {
            SettingsView(preferences: browser.preferences, history: browser.history, sitePrivacy: browser.sitePrivacy,
                         favorites: browser.favorites,
                         clearRegularWebsiteData: { browser.clearRegularWebsiteData(completion: $0) },
                         applyPrivacyPreferences: { browser.applyPrivacyPreferences() },
                         applySessionPreferences: { browser.applySessionPreferences() })
                .environmentObject(browser)
        }
        .sheet(isPresented: $browser.showsDownloads) {
            DownloadsView(downloadCenter: browser.downloadCenter).environmentObject(browser)
        }
        .sheet(isPresented: $browser.showsLibrary) {
            LibraryView(bookmarks: browser.bookmarks, history: browser.history).environmentObject(browser)
        }
        .sheet(isPresented: $browser.showsSitePrivacy) {
            SitePrivacyView(sitePrivacy: browser.sitePrivacy).environmentObject(browser)
        }
        .background {
            ZStack {
                PermissionPromptHost(broker: browser.permissionBroker)
                ScriptDialogHost(broker: browser.scriptDialogs)
                PrivateBrowsingShield(isEnabled: coversForPrivacy)
                    .frame(width: 0, height: 0)
            }
        }
        .onAppear { browser.updateSceneActivity(isActive: scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in browser.updateSceneActivity(isActive: phase == .active) }
        .tint(.accentColor)
    }

    private var browserContent: some View {
        Group {
            if let tab = browser.selectedTab {
                BrowserPage(tab: tab, preferences: browser.preferences)
                    .id(tab.id)
            }
        }
    }
}

private struct BrowserPage: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @ObservedObject var preferences: BrowserPreferences
    @State private var navigationHeight: CGFloat = 0

    private var controlsAtBottom: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && preferences.phoneControlsPosition == .bottom
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            // Keep WebKit mounted before the first request so its policy and permission delegates are ready.
            WebView(tab: tab, browser: browser)
                .ignoresSafeArea(.container, edges: .bottom)
            if tab.url == nil && tab.navigationError == nil && !tab.awaitsRestoredLoad {
                StartPage(preferences: browser.preferences, bookmarks: browser.bookmarks, favorites: browser.favorites)
                    .safeAreaInset(edge: controlsAtBottom ? .bottom : .top, spacing: 0) {
                        Color.clear.frame(height: navigationHeight)
                    }
            }
            if let error = tab.navigationError {
                PageLoadErrorView(tab: tab, message: error)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
                .safeAreaInset(edge: controlsAtBottom ? .bottom : .top, spacing: 0) {
                    Color.clear.frame(height: navigationHeight)
                }
            }
        }
        .overlay(alignment: controlsAtBottom ? .bottom : .top) {
            VStack(spacing: 0) {
                if controlsAtBottom { pageAccessories }
                BrowserToolbar(tab: tab, preferences: preferences)
                if browser.showsFindBar {
                    FindBar()
                }
                if !controlsAtBottom { pageAccessories }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                navigationHeight = height
            }
        }
        .onChange(of: navigationHeight, initial: true) { _, height in
            updateNavigationInsets(height)
        }
        .onChange(of: controlsAtBottom) { _, _ in
            updateNavigationInsets(navigationHeight)
        }
        .onChange(of: tab.url) { _, _ in
            browser.closeFindBar()
            browser.syncAddressWithPage()
            browser.recordCurrentVisit()
        }
        .onChange(of: tab.title) { _, _ in
            browser.recordCurrentVisit()
        }
    }

    /// Suggestions and download notices sit next to the controls and are not counted in the page inset.
    private var pageAccessories: some View {
        VStack(spacing: 8) {
            if browser.isEditingAddress && tab.id == browser.selectedTabID {
                AddressSuggestions()
            }
            DownloadNoticeBanner(downloadCenter: browser.downloadCenter)
        }
        .padding(.horizontal, 12)
        .frame(height: 0, alignment: controlsAtBottom ? .bottom : .top)
    }

    private func updateNavigationInsets(_ height: CGFloat) {
        BrowserChromeLayout.apply(topInset: controlsAtBottom ? 0 : height,
                                  bottomInset: controlsAtBottom ? height : 0,
                                  to: tab.webView.scrollView)
    }
}

private struct AddressSuggestions: View {
    @EnvironmentObject private var browser: BrowserStore

    var body: some View {
        let suggestions = browser.addressSuggestions(for: browser.addressDraft)
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { site in
                    Button {
                        guard let url = site.url else { return }
                        browser.endAddressEditing()
                        browser.open(url)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: browser.bookmarks.contains(site.url) ? "bookmark" : "clock")
                                .foregroundStyle(.secondary).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(site.title).lineLimit(1)
                                Text(site.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(site.title)
                    .accessibilityHint(site.address)
                }
            }
            .padding(.vertical, 6)
            .acuteGlass(cornerRadius: 22)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Suggestions from bookmarks and history")
            .accessibilityIdentifier("addressSuggestions")
        }
    }
}

private struct DownloadNoticeBanner: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var downloadCenter: DownloadCenter

    var body: some View {
        if let notice = downloadCenter.notice {
            HStack(spacing: 12) {
                Image(systemName: symbol(for: notice.state)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: notice.state)).font(.subheadline.weight(.semibold))
                    Text(notice.filename).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 0)
                Button("Show") {
                    downloadCenter.dismissNotice(notice.id)
                    browser.showsDownloads = true
                }
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .acuteGlass(cornerRadius: 22)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("downloadNotice")
            .task(id: notice.id) {
                AccessibilityNotification.Announcement("\(title(for: notice.state)): \(notice.filename)").post()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                downloadCenter.dismissNotice(notice.id)
            }
        }
    }

    private func title(for state: DownloadState) -> String {
        switch state {
        case .downloading: return "Downloading"
        case .finished: return "Download Complete"
        case .failed: return "Download Failed"
        }
    }

    private func symbol(for state: DownloadState) -> String {
        switch state {
        case .downloading: return "arrow.down.circle"
        case .finished: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

private struct PermissionPromptHost: View {
    @ObservedObject var broker: PermissionBroker

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .alert(broker.pendingRequest.map { "Allow \($0.kind.title)?" } ?? "Allow access?", isPresented: Binding(
                get: { broker.pendingRequest != nil }, set: { _ in }
            ), presenting: broker.pendingRequest) { request in
                Button("Allow Once") { broker.decide(.allowOnce, requestID: request.id) }
                Button("Always Allow on This Site") { broker.decide(.alwaysAllow, requestID: request.id) }
                Button("Don’t Allow", role: .cancel) { broker.decide(.deny, requestID: request.id) }
            } message: { request in
                Text("\(request.host) is requesting access. Acute Web will deny access unless you explicitly allow it. You can change this later in Site Privacy.")
            }
    }
}
