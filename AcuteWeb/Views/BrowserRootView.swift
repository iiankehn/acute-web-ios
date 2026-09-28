import SwiftUI

struct BrowserRootView: View {
    @EnvironmentObject private var browser: BrowserStore
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
            PermissionPromptHost(broker: browser.permissionBroker)
        }
        .tint(.accentColor)
    }

    private var browserContent: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            if let tab = browser.selectedTab {
                if tab.url == nil {
                    StartPage()
                } else {
                    WebView(
                        tab: tab,
                        downloadCenter: browser.downloadCenter,
                        permissionBroker: browser.permissionBroker,
                        sitePrivacy: browser.sitePrivacy
                    )
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                BrowserToolbar()
                if browser.showsFindBar {
                    FindBar()
                }
                if let tab = browser.selectedTab, tab.isLoading {
                    ProgressView(value: tab.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }
            }
        }
        .onChange(of: browser.selectedTab?.url) { _, _ in
            browser.refreshAddress()
            browser.recordCurrentVisit()
        }
    }
}

private struct PermissionPromptHost: View {
    @ObservedObject var broker: PermissionBroker

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .alert(item: $broker.pendingRequest) { request in
            Alert(
                title: Text("Allow \(request.kind.title)?"),
                message: Text("\(request.host) is requesting access. Acute Web will deny access unless you explicitly allow it."),
                primaryButton: .default(Text("Allow Once")) { broker.resolve(.grant) },
                secondaryButton: .cancel(Text("Don’t Allow")) { broker.resolve(.deny) }
            )
        }
    }
}
