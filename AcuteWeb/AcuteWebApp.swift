import SwiftUI

@main
struct AcuteWebApp: App {
    /// Bookmarks, history, downloads and settings are shared; each window keeps its own tabs.
    @MainActor private static let services = BrowserServices()

    var body: some Scene {
        WindowGroup {
            BrowserWindow(services: Self.services)
        }
        .commands {
            BrowserCommands()
        }
    }
}

/// Gives each window its own saved tab session. The first window keeps the original session.
private struct BrowserWindow: View {
    let services: BrowserServices
    @SceneStorage("acuteSessionKey") private var sessionKey = ""
    @State private var claimedKey: String?

    var body: some View {
        if let claimedKey {
            BrowserWindowContent(services: services, sessionKey: claimedKey)
        } else {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
                .onAppear {
                    let key = services.claimSessionKey(preferred: sessionKey)
                    sessionKey = key
                    claimedKey = key
                }
        }
    }
}

private struct BrowserWindowContent: View {
    @StateObject private var browser: BrowserStore
    @Environment(\.scenePhase) private var scenePhase

    init(services: BrowserServices, sessionKey: String) {
        _browser = StateObject(wrappedValue: BrowserStore(
            sessionStore: BrowserSessionStore(defaults: services.defaults, defaultsKey: sessionKey), services: services))
    }

    var body: some View {
        BrowserRootView()
            .environmentObject(browser)
            .focusedSceneObject(browser)
            .onAppear {
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains(UITestNavigationFixture.launchArgument),
                   let tab = browser.selectedTab, tab.lastRequestedURL == nil {
                    let url = URL(string: "acute-ui-fixture://pages/first")!
                    tab.lastRequestedURL = url
                    tab.webView.load(URLRequest(url: url))
                }
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
}
