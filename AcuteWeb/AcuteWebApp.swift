import SwiftUI

@main
struct AcuteWebApp: App {
    @StateObject private var browser = BrowserStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            BrowserRootView()
                .environmentObject(browser)
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
