import SwiftUI

struct BrowserCommands: Commands {
    @ObservedObject var browser: BrowserStore

    var body: some Commands {
        CommandMenu("Browser") {
            Button("New Tab") { browser.newTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button("New Private Tab") { browser.newTab(isPrivate: true) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Close Tab") {
                if let tab = browser.selectedTab { browser.close(tab) }
            }
            .keyboardShortcut("w", modifiers: .command)
            Divider()
            Button("Reload") { browser.selectedTab?.webView.reload() }
                .keyboardShortcut("r", modifiers: .command)
            Button("Find on Page") { browser.showsFindBar = true }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(browser.selectedTab?.url == nil)
            Button(browser.selectedTab?.usesDesktopSite == true ? "Request Mobile Site" : "Request Desktop Site") {
                browser.toggleDesktopSite()
            }
            .disabled(browser.selectedTab?.url == nil)
        }
    }
}
