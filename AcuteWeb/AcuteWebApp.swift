import SwiftUI

@main
struct AcuteWebApp: App {
    @StateObject private var browser = BrowserStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            BrowserRootView()
                .environmentObject(browser)
                .onAppear {
#if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-acuteUITestPageError"),
                       let tab = browser.selectedTab, tab.lastRequestedURL == nil {
                        tab.lastRequestedURL = URL(string: "https://acute-error.invalid")!
                        tab.navigationError = "The test website could not be reached."
                        browser.refreshAddress()
                    }
                    if ProcessInfo.processInfo.arguments.contains("-acuteUITestRenderedPage"),
                       let tab = browser.selectedTab, tab.lastRequestedURL == nil {
                        let url = URL(string: "https://acute-fixture.invalid")!
                        tab.lastRequestedURL = url
                        tab.webView.loadHTMLString("""
                            <meta name="viewport" content="width=device-width,initial-scale=1">
                            <title>Acute navigation fixture</title>
                            <body><h1>Loaded page</h1>
                            <button style="padding:16px" onclick="history.pushState({}, '', '/next'); document.title='Second fixture page'">Next fixture page</button>
                            <script>addEventListener('popstate', () => { document.title = location.pathname === '/next' ? 'Second fixture page' : 'Acute navigation fixture'; });</script>
                            </body>
                            """, baseURL: url)
                    }
#endif
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        browser.saveSession()
                    }
                }
        }
        .commands {
            BrowserCommands(browser: browser)
        }
    }
}
