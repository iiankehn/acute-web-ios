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
        .tint(.cyan)
    }

    private var browserContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let tab = browser.selectedTab {
                if tab.url == nil {
                    StartPage()
                } else {
                    WebView(tab: tab)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                BrowserToolbar()
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
