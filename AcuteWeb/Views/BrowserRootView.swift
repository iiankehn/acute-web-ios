import SwiftUI

struct BrowserRootView: View {
    @EnvironmentObject private var browser: BrowserStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
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
            SettingsView(preferences: browser.preferences, history: browser.history) {
                browser.applyPrivacyPreferences()
            } applySessionPreferences: {
                browser.saveSession()
            }
        }
        .sheet(isPresented: $browser.showsDownloads) {
            DownloadsView(downloadCenter: browser.downloadCenter)
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
                PrivateBrowsingShield(isEnabled: scenePhase != .active && browser.selectedTab?.isPrivate == true)
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
                BrowserPage(tab: tab)
                    .id(tab.id)
            }
        }
    }
}

private struct BrowserPage: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            // Keep WebKit mounted before the first request so its policy and permission delegates are ready.
            WebView(
                tab: tab,
                downloadCenter: browser.downloadCenter,
                permissionBroker: browser.permissionBroker,
                sitePrivacy: browser.sitePrivacy,
                openLink: { request, isPrivate in browser.openInNewTab(request, isPrivate: isPrivate) },
                scriptDialogs: browser.scriptDialogs,
                canPresentDialogs: { browser.allowsWebsitePrompts && browser.selectedTabID == tab.id },
                prepareNavigation: { webView, url, completion in
                    browser.prepareNavigation(webView, url: url, completion: completion)
                }
            )
            .ignoresSafeArea(.container, edges: .bottom)
            if tab.url == nil && tab.navigationError == nil {
                StartPage(preferences: browser.preferences, bookmarks: browser.bookmarks)
            }
            if let error = tab.navigationError {
                ContentUnavailableView {
                    Label("Unable to Load Page", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { browser.retryNavigation() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                BrowserToolbar(tab: tab)
                if browser.showsFindBar {
                    FindBar()
                }
                if tab.isLoading {
                    ProgressView(value: tab.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }
            }
        }
        .onChange(of: tab.url) { _, _ in
            browser.closeFindBar()
            browser.refreshAddress()
            browser.recordCurrentVisit()
        }
        .onChange(of: tab.title) { _, _ in
            browser.recordCurrentVisit()
        }
    }
}

private struct PermissionPromptHost: View {
    @ObservedObject var broker: PermissionBroker

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .alert(item: Binding(get: { broker.pendingRequest }, set: { _ in })) { request in
            Alert(
                title: Text("Allow \(request.kind.title)?"),
                message: Text("\(request.host) is requesting access. Acute Web will deny access unless you explicitly allow it."),
                primaryButton: .default(Text("Allow Once")) { broker.resolve(.grant, requestID: request.id) },
                secondaryButton: .cancel(Text("Don’t Allow")) { broker.resolve(.deny, requestID: request.id) }
            )
        }
    }
}
