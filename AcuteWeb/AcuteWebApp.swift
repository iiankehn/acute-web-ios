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
                    if ProcessInfo.processInfo.arguments.contains("-acuteUITestRenderedPage"),
                       let tab = browser.selectedTab, tab.lastRequestedURL == nil {
                        let url = URL(string: "https://acute-fixture.invalid")!
                        tab.lastRequestedURL = url
                        tab.webView.loadHTMLString("<title>Acute navigation fixture</title><body><h1>Loaded page</h1></body>", baseURL: url)
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
