import SwiftUI

struct BrowserCommands: Commands {
    @ObservedObject var browser: BrowserStore

    var body: some Commands {
        CommandMenu("Tabs") {
            Button("New Tab") { browser.newTab() }.keyboardShortcut("t", modifiers: .command)
            Button("New Private Tab") { browser.newTab(isPrivate: true) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Close Tab") {
                if let tab = browser.selectedTab { browser.close(tab) }
            }
            .keyboardShortcut("w", modifiers: .command)
            Button("Show All Tabs") { browser.selectedTab?.captureSnapshot(); browser.showsTabs = true }
            Divider()
            Button("Reopen Closed Tab") { browser.reopenLastClosedTab() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(browser.recentlyClosed.isEmpty)
            Button("Next Tab") { browser.selectAdjacentTab() }
                .keyboardShortcut(.tab, modifiers: .control).disabled(browser.tabs.count < 2)
            Button("Previous Tab") { browser.selectAdjacentTab(backwards: true) }
                .keyboardShortcut(.tab, modifiers: [.control, .shift]).disabled(browser.tabs.count < 2)
        }
        CommandMenu("Navigate") {
            Button("Focus Address") { browser.focusAddress() }.keyboardShortcut("l", modifiers: .command)
            if let tab = browser.selectedTab { NavigationCommands(browser: browser, tab: tab) }
        }
        CommandMenu("Page") {
            if let tab = browser.selectedTab { PageCommands(browser: browser, tab: tab) }
        }
        CommandMenu("Library") {
            Button("Bookmarks and History") { browser.showsLibrary = true }
            Button("Downloads") { browser.showsDownloads = true }
            Divider()
            Button("Settings") { browser.showsSettings = true }.keyboardShortcut(",", modifiers: .command)
        }
    }
}

private struct NavigationCommands: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab

    var body: some View {
        Button("Back") { tab.webView.goBack() }
            .keyboardShortcut("[", modifiers: .command).disabled(!tab.canGoBack)
        Button("Forward") { tab.webView.goForward() }
            .keyboardShortcut("]", modifiers: .command).disabled(!tab.canGoForward)
        Button("Reload") {
            if tab.navigationError != nil { browser.retryNavigation() } else { tab.webView.reload() }
        }
        .keyboardShortcut("r", modifiers: .command).disabled(tab.url == nil && tab.lastRequestedURL == nil)
        Button("Stop Loading") { tab.webView.stopLoading() }
            .keyboardShortcut(".", modifiers: .command).disabled(!tab.isLoading)
        Button("Start Page") { browser.showStartPage() }
            .keyboardShortcut("h", modifiers: [.command, .shift])
    }
}

private struct PageCommands: View {
    @ObservedObject var browser: BrowserStore
    @ObservedObject var tab: BrowserTab

    var body: some View {
        Button("Find on Page") { browser.showsFindBar = true }
            .keyboardShortcut("f", modifiers: .command).disabled(tab.url == nil)
        Button(tab.usesDesktopSite ? "Request Mobile Site" : "Request Desktop Site") { browser.toggleDesktopSite() }
            .disabled(tab.url == nil)
        Button("Site Privacy") { browser.showsSitePrivacy = true }.disabled(tab.url == nil)
        Divider()
        Button("Zoom In") { browser.setPageZoom(tab.pageZoom + 0.25) }
            .keyboardShortcut("=", modifiers: .command).disabled(tab.url == nil || tab.pageZoom >= 2)
        Button("Zoom Out") { browser.setPageZoom(tab.pageZoom - 0.25) }
            .keyboardShortcut("-", modifiers: .command).disabled(tab.url == nil || tab.pageZoom <= 0.5)
        Button("Actual Size") { browser.setPageZoom(1) }
            .keyboardShortcut("0", modifiers: .command).disabled(tab.url == nil || tab.pageZoom == 1)
        Button(browser.bookmarks.contains(tab.url) ? "Remove Bookmark" : "Add Bookmark") { browser.toggleBookmark() }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(tab.isPrivate || tab.url.flatMap { WebAddress.url($0.absoluteString, allowMissingScheme: false) } == nil)
    }
}
