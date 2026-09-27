import SwiftUI

struct BrowserRootView: View {
    @EnvironmentObject private var browser: BrowserStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationSplitView {
            if horizontalSizeClass == .regular {
                TabSidebar()
                    .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 340)
            }
        } detail: {
            browserContent
        }
        .sheet(isPresented: $browser.showsTabs) {
            NavigationStack { TabGrid() }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $browser.showsSettings) {
            SettingsView(preferences: browser.preferences) {
                browser.applyPrivacyPreferences()
            }
        }
        .sheet(isPresented: $browser.showsDownloads) {
            DownloadsView(downloadCenter: browser.downloadCenter)
        }
        .background {
            PermissionPromptHost(broker: browser.permissionBroker)
        }
        .tint(.cyan)
    }

    private var browserContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let tab = browser.selectedTab {
                if tab.url == nil {
                    StartPage()
                } else {
                    WebView(
                        tab: tab,
                        downloadCenter: browser.downloadCenter,
                        permissionBroker: browser.permissionBroker
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
                        .tint(.cyan)
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
