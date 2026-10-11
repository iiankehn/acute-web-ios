import SwiftUI

struct BrowserToolbar: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var addressFocused: Bool

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                VStack(spacing: 4) {
                    addressBar
                    HStack(spacing: 0) {
                        navigationButtons
                        Spacer(minLength: 8)
                        bookmarkButton
                        tabsButton
                        moreMenu
                    }
                }
            } else {
                HStack(spacing: 8) {
                    navigationButtons
                    addressBar
                    bookmarkButton
                    moreMenu
                }
            }
        }
        .onChange(of: browser.addressFocusRequest) { _, _ in
            addressFocused = true
        }
        .alert("Unable to Open Address", isPresented: Binding(
            get: { browser.addressInputError != nil }, set: { if !$0 { browser.addressInputError = nil } }
        )) {
            Button("OK") { browser.addressInputError = nil }
        } message: {
            Text(browser.addressInputError ?? "")
        }
        .buttonStyle(.plain)
        .font(.body.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var addressSymbol: String {
        if browser.selectedTab?.isPrivate == true { return "hand.raised.fill" }
        guard let url = browser.selectedTab?.url else { return "magnifyingglass" }
        return url.scheme?.lowercased() == "https" ? "lock.fill" : "globe"
    }

    private var navigationButtons: some View {
        Group {
            Button { browser.selectedTab?.webView.goBack() } label: {
                Image(systemName: "chevron.backward")
            }
            .accessibilityLabel("Back")
            .frame(minWidth: 44, minHeight: 44)
            .disabled(browser.selectedTab?.canGoBack != true)

            Button { browser.selectedTab?.webView.goForward() } label: {
                Image(systemName: "chevron.forward")
            }
            .accessibilityLabel("Forward")
            .frame(minWidth: 44, minHeight: 44)
            .disabled(browser.selectedTab?.canGoForward != true)

        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: addressSymbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            TextField("Search or enter address", text: $browser.addressDraft)
            .accessibilityIdentifier("addressField")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.webSearch)
            .focused($addressFocused)
            .submitLabel(.go)
            .onSubmit {
                addressFocused = false
                browser.navigate()
            }
            Button {
                if browser.selectedTab?.isLoading == true {
                    browser.selectedTab?.webView.stopLoading()
                } else {
                    browser.selectedTab?.webView.reload()
                }
            } label: {
                Image(systemName: browser.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise")
            }
            .accessibilityLabel(browser.selectedTab?.isLoading == true ? "Stop" : "Reload")
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .acuteGlass(cornerRadius: 22)
        .layoutPriority(1)

    }

    private var tabsButton: some View {
        Button {
            browser.selectedTab?.captureSnapshot()
            browser.showsTabs = true
        } label: {
            Image(systemName: "square.on.square")
            .overlay(alignment: .center) {
                Text("\(browser.tabs.count)").font(.system(size: 8, weight: .bold))
            }
        }
        .accessibilityLabel("Tabs")
        .accessibilityValue("\(browser.tabs.count) open")
        .frame(minWidth: 44, minHeight: 44)
    }

    private var bookmarkButton: some View {
        Group {
            if let url = tab.url, WebAddress.url(url.absoluteString, allowMissingScheme: false) != nil, !tab.isPrivate {
                Button { browser.toggleBookmark() } label: {
                    Image(systemName: browser.bookmarks.contains(browser.selectedTab?.url) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(browser.bookmarks.contains(browser.selectedTab?.url) ? "Remove Bookmark" : "Add Bookmark")
                .frame(minWidth: 44, minHeight: 44)
            }

        }
    }

    private var moreMenu: some View {
        Menu {
            Button("New Tab", systemImage: "plus") { browser.newTab() }
            Button("New Private Tab", systemImage: "hand.raised.fill") { browser.newTab(isPrivate: true) }
            Button("Reopen Closed Tab", systemImage: "arrow.uturn.backward") {
                browser.reopenLastClosedTab()
            }
            .disabled(browser.recentlyClosed.isEmpty)
            Divider()
            Button("Start Page", systemImage: "house") { browser.showStartPage() }
            Menu {
                ForEach([50, 75, 100, 125, 150, 175, 200], id: \.self) { percent in
                    Button {
                        browser.setPageZoom(Double(percent) / 100)
                    } label: {
                        if Int((tab.pageZoom * 100).rounded()) == percent {
                            Label("\(percent)%", systemImage: "checkmark")
                        } else {
                            Text("\(percent)%")
                        }
                    }
                }
            } label: {
                Label("Page Zoom: \(Int((tab.pageZoom * 100).rounded()))%", systemImage: "textformat.size")
            }
            .disabled(tab.url == nil)
            Button("Find on Page", systemImage: "text.magnifyingglass") {
                browser.showsFindBar = true
            }
            .disabled(browser.selectedTab?.url == nil)
            Button(
            browser.selectedTab?.usesDesktopSite == true ? "Request Mobile Site" : "Request Desktop Site",
            systemImage: browser.selectedTab?.usesDesktopSite == true ? "iphone" : "desktopcomputer"
            ) {
                browser.toggleDesktopSite()
            }
            .disabled(browser.selectedTab?.url == nil)
            Button("Downloads", systemImage: "arrow.down.circle") { browser.showsDownloads = true }
            Button("Bookmarks and History", systemImage: "books.vertical") { browser.showsLibrary = true }
            Button("Site Privacy", systemImage: "shield.lefthalf.filled") { browser.showsSitePrivacy = true }
            .disabled(browser.selectedTab?.url == nil)
            if let url = browser.selectedTab?.url {
                ShareLink(item: url)
            }
            Button("Settings", systemImage: "gearshape") { browser.showsSettings = true }
        } label: {
            Image(systemName: "ellipsis")
            .frame(width: 32, height: 32)
        }
        .accessibilityLabel("More")
        .frame(minWidth: 44, minHeight: 44)
    }
}
