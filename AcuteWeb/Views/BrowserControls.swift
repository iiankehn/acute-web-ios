import SwiftUI
import WebKit

/// Back or Forward. Tap to move one page; touch and hold to choose from the tab's history.
struct HistoryButton: View {
    enum Direction { case back, forward }

    @ObservedObject var tab: BrowserTab
    let direction: Direction
    let height: CGFloat

    private var items: [WKBackForwardListItem] {
        direction == .back ? Array(tab.webView.backForwardList.backList.reversed()) : tab.webView.backForwardList.forwardList
    }

    var body: some View {
        Menu {
            ForEach(Array(items.prefix(15).enumerated()), id: \.offset) { _, item in
                Button(item.title?.isEmpty == false ? item.title! : (item.url.host ?? item.url.absoluteString)) {
                    tab.webView.go(to: item)
                }
            }
        } label: {
            Image(systemName: direction == .back ? "chevron.backward" : "chevron.forward")
                .frame(width: 44, height: height)
                .contentShape(Rectangle())
        } primaryAction: {
            if direction == .back { tab.webView.goBack() } else { tab.webView.goForward() }
        }
        .menuIndicator(.hidden)
        .disabled(direction == .back ? !tab.canGoBack : !tab.canGoForward)
        .accessibilityLabel(direction == .back ? "Back" : "Forward")
        .accessibilityHint("Touch and hold for history")
    }
}

/// Opens the tab overview and shows how many tabs are open.
struct TabsOverviewButton: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    let height: CGFloat
    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 9

    var body: some View {
        Button {
            tab.captureSnapshot()
            browser.showsTabs = true
        } label: {
            Image(systemName: "square.on.square")
                .overlay {
                    Text(browser.tabs.count > 99 ? "∞" : "\(browser.tabs.count)")
                        .font(.system(size: min(badgeSize, 13), weight: .bold))
                        .minimumScaleFactor(0.6)
                        .allowsHitTesting(false)
                        // The count stays small to fit inside the symbol; the button's value reads it out.
                        .accessibilityIdentifier("tabCountBadge")
                }
                .frame(width: 44, height: height).contentShape(Rectangle())
        }
        .accessibilityLabel("Tabs").accessibilityValue("\(browser.tabs.count) open")
        .accessibilityShowsLargeContentViewer {
            Label("\(browser.tabs.count) tabs", systemImage: "square.on.square")
        }
    }
}

/// The More menu. `doneEditing` adds Done Editing while the address field is expanded.
struct BrowserMoreMenu: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    let height: CGFloat
    var doneEditing: (() -> Void)?

    var body: some View {
        Menu {
            // The heading keeps tab actions off the menu's first row, which iOS 27 can leave unresponsive to taps.
            Section("Tabs") {
                Button("New Tab", systemImage: "plus") { browser.newTab() }
                Button("New Private Tab", systemImage: "hand.raised.fill") { browser.newTab(isPrivate: true) }
                Button("Show All Tabs", systemImage: "square.on.square") {
                    tab.captureSnapshot(); browser.showsTabs = true
                }
                Button("Reopen Closed Tab", systemImage: "arrow.uturn.backward") { browser.reopenLastClosedTab() }
                    .disabled(browser.recentlyClosed.isEmpty)
            }
            Menu("Page Tools", systemImage: "doc.text") {
                if let doneEditing {
                    Button("Done Editing", systemImage: "checkmark", action: doneEditing)
                        .accessibilityIdentifier("finishAddressEditing")
                }
                Button("Start Page", systemImage: "house") { browser.showStartPage() }
                Button("Reload", systemImage: "arrow.clockwise") { tab.webView.reload() }.disabled(tab.url == nil)
                Button("Find on Page", systemImage: "text.magnifyingglass") { browser.showsFindBar = true }
                    .disabled(tab.url == nil)
                pageZoomMenu
                Button(tab.usesDesktopSite ? "Request Mobile Site" : "Request Desktop Site", systemImage: "desktopcomputer") {
                    browser.toggleDesktopSite()
                }.disabled(tab.url == nil)
                if let url = tab.url { ShareLink(item: url) }
            }
            Menu("Saved Content", systemImage: "books.vertical") {
                Button(browser.bookmarks.contains(tab.url) ? "Remove Bookmark" : "Add Bookmark", systemImage: "bookmark") {
                    browser.toggleBookmark()
                }
                .disabled(tab.isPrivate || tab.url.flatMap { WebAddress.url($0.absoluteString, allowMissingScheme: false) } == nil)
                Button(browser.favorites.contains(tab.url) ? "Remove from Favorites" : "Add to Favorites", systemImage: "star") {
                    browser.toggleFavorite()
                }
                .disabled(tab.isPrivate || tab.url.flatMap { WebAddress.url($0.absoluteString, allowMissingScheme: false) } == nil)
                Button("Bookmarks and History", systemImage: "books.vertical") { browser.showsLibrary = true }
                Button("Downloads", systemImage: "arrow.down.circle") { browser.showsDownloads = true }
            }
            Menu("Privacy", systemImage: "shield.lefthalf.filled") {
                Button("Site Privacy", systemImage: "shield.lefthalf.filled") { browser.showsSitePrivacy = true }
                    .disabled(tab.url == nil)
            }
            Divider()
            Button("Settings", systemImage: "gearshape") { browser.showsSettings = true }
        } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: height).contentShape(Rectangle())
        }
        .accessibilityLabel("More")
    }

    private var pageZoomMenu: some View {
        Menu {
            ForEach([50, 75, 100, 125, 150, 175, 200], id: \.self) { percent in
                Button { browser.setPageZoom(Double(percent) / 100) } label: {
                    if Int((tab.pageZoom * 100).rounded()) == percent {
                        Label("\(percent)%", systemImage: "checkmark")
                    } else { Text("\(percent)%") }
                }
            }
        } label: {
            Label("Page Zoom: \(Int((tab.pageZoom * 100).rounded()))%", systemImage: "textformat.size")
        }
        .disabled(tab.url == nil)
    }
}

/// Back, Forward, New Tab, Tabs and More on the side of the window, where the system places
/// bars vertically (iPhone Duo's outer display and open landscape).
struct NavigationRail: View {
    /// The rail's width including its padding, for layout next to it.
    static let width: CGFloat = 64

    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 44

    var body: some View {
        AcuteGlassContainer(spacing: 8) {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    HistoryButton(tab: tab, direction: .back, height: buttonSize)
                    HistoryButton(tab: tab, direction: .forward, height: buttonSize)
                }
                .padding(.vertical, 4)
                .acuteGlass(cornerRadius: (buttonSize + 8) / 2)
                Spacer(minLength: 12)
                VStack(spacing: 0) {
                    Button { browser.newTab() } label: {
                        Image(systemName: "plus").frame(width: 44, height: buttonSize).contentShape(Rectangle())
                    }
                    .accessibilityLabel("New Tab")
                    TabsOverviewButton(tab: tab, height: buttonSize)
                    BrowserMoreMenu(tab: tab, height: buttonSize)
                }
                .padding(.vertical, 4)
                .acuteGlass(cornerRadius: (buttonSize + 8) / 2)
            }
            .frame(width: 52)
        }
        .buttonStyle(.plain)
        .font(.body.weight(.medium))
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .avoidingOcclusions()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("navigationRail")
    }
}
