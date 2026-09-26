import SwiftUI

@main
struct AcuteWebApp: App {
    @StateObject private var browser = BrowserStore()

    var body: some Scene {
        WindowGroup {
            BrowserRootView()
                .environmentObject(browser)
        }
        .commands {
            BrowserCommands(browser: browser)
        }
    }
}

