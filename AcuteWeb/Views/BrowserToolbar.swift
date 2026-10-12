import SwiftUI

struct BrowserToolbar: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @ObservedObject var preferences: BrowserPreferences
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var addressFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controlsExpanded = false

    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    private var isCondensed: Bool {
        isPhone && preferences.condensesPhoneControls && tab.hasRenderedPage && !tab.isLoading && tab.navigationError == nil
            && !controlsExpanded && !addressFocused && !browser.showsFindBar
    }

    var body: some View {
        AcuteGlassContainer {
            if isCondensed {
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                    Button {
                        controlsExpanded = true
                        addressFocused = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: addressSymbol).font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                if preferences.showsCompactPageTitle {
                                    Text(tab.title == "New Tab" ? (tab.url?.host ?? tab.title) : tab.title)
                                        .font(.subheadline.weight(.semibold)).lineLimit(1)
                                    if let host = tab.url?.host {
                                        Text(host).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                } else {
                                    Text(tab.url?.host ?? tab.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Capsule())
                    }
                    .accessibilityLabel("Edit Address")
                    .accessibilityValue("\(tab.title), \(tab.url?.absoluteString ?? "")")
                    .accessibilityIdentifier("condensedAddress")
                    pageLoadButton.padding(.trailing, 4)
                    }
                    .acuteGlass(cornerRadius: 22)
                    HStack(spacing: 0) { tabsButton; moreMenu }
                        .acuteGlass(cornerRadius: 22)
                }
            } else if isPhone || horizontalSizeClass == .compact {
                VStack(spacing: 8) {
                    addressBar
                    HStack(spacing: 0) {
                        navigationButtons
                        Spacer(minLength: 8)
                        if isPhone && preferences.condensesPhoneControls && tab.hasRenderedPage && !tab.isLoading && tab.navigationError == nil {
                            Button {
                                addressFocused = false
                                controlsExpanded = false
                            } label: {
                                Image(systemName: "chevron.up")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Condense Controls")
                        }
                        bookmarkButton
                        tabsButton
                        moreMenu
                    }
                    .padding(.horizontal, 8)
                    .acuteGlass(cornerRadius: 22)
                }
            } else {
                VStack(spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            HStack(spacing: 0) { navigationButtons }
                                .acuteGlass(cornerRadius: 22)
                            addressBar.frame(minWidth: 240)
                            HStack(spacing: 0) { bookmarkButton; tabsButton; moreMenu }
                                .acuteGlass(cornerRadius: 22)
                        }
                        VStack(spacing: 8) {
                            addressBar
                            HStack(spacing: 0) {
                                navigationButtons
                                Spacer(minLength: 8)
                                bookmarkButton
                                tabsButton
                                moreMenu
                            }
                            .padding(.horizontal, 8)
                            .acuteGlass(cornerRadius: 22)
                        }
                    }
                    DesktopTabStrip()
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isCondensed)
        .onChange(of: tab.hasRenderedPage) { _, rendered in
            if rendered { controlsExpanded = false }
        }
        .onChange(of: browser.addressFocusRequest) { _, _ in
            controlsExpanded = true
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
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            .disabled(browser.selectedTab?.canGoBack != true)

            Button { browser.selectedTab?.webView.goForward() } label: {
                Image(systemName: "chevron.forward")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Forward")
            .disabled(browser.selectedTab?.canGoForward != true)

        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: addressSymbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            TextField("Search or enter address", text: $browser.addressDraft)
            .accessibilityLabel("Search or enter address")
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
            if addressFocused {
                Button {
                    browser.addressDraft = ""
                    browser.addressInputError = nil
                    addressFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear Address")
                .accessibilityIdentifier("clearAddress")
                .disabled(browser.addressDraft.isEmpty)
            }
            pageLoadButton
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .acuteGlass(cornerRadius: 22)
        .overlay(alignment: .bottom) {
            if tab.isLoading {
                ProgressView(value: tab.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 3)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Loading page")
                    .accessibilityIdentifier("addressLoadingProgress")
            }
        }
        .layoutPriority(1)

    }

    private var pageLoadButton: some View {
        Button {
            if tab.isLoading {
                tab.webView.stopLoading()
            } else if tab.navigationError != nil {
                browser.retryNavigation()
            } else {
                tab.webView.reload()
            }
        } label: {
            Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(tab.isLoading ? "Stop" : "Reload")
        .accessibilityIdentifier("pageLoadControl")
        .disabled(!tab.isLoading && tab.url == nil && tab.lastRequestedURL == nil)
    }

    private var tabsButton: some View {
        Button {
            browser.selectedTab?.captureSnapshot()
            browser.showsTabs = true
        } label: {
            Image(systemName: "square.on.square")
            .overlay(alignment: .center) {
                Text("\(browser.tabs.count)").font(.system(size: 8, weight: .bold))
                    .allowsHitTesting(false)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Tabs")
        .accessibilityValue("\(browser.tabs.count) open")
    }

    private var bookmarkButton: some View {
        Group {
            if let url = tab.url, WebAddress.url(url.absoluteString, allowMissingScheme: false) != nil, !tab.isPrivate {
                Button { browser.toggleBookmark() } label: {
                    Image(systemName: browser.bookmarks.contains(browser.selectedTab?.url) ? "bookmark.fill" : "bookmark")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(browser.bookmarks.contains(browser.selectedTab?.url) ? "Remove Bookmark" : "Add Bookmark")
            }

        }
    }

    private var moreMenu: some View {
        Menu {
            if isCondensed {
                Button("Back", systemImage: "chevron.backward") { tab.webView.goBack() }
                    .disabled(!tab.canGoBack)
                Button("Forward", systemImage: "chevron.forward") { tab.webView.goForward() }
                    .disabled(!tab.canGoForward)
                Button("Reload", systemImage: "arrow.clockwise") { tab.webView.reload() }
                Button(browser.bookmarks.contains(tab.url) ? "Remove Bookmark" : "Add Bookmark", systemImage: "bookmark") {
                    browser.toggleBookmark()
                }
                .disabled(tab.isPrivate || tab.url.flatMap { WebAddress.url($0.absoluteString, allowMissingScheme: false) } == nil)
                Divider()
            }
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
            Button("Site Privacy", systemImage: "shield.lefthalf.filled") { browser.showsSitePrivacy = true }
            .disabled(browser.selectedTab?.url == nil)
            if let url = browser.selectedTab?.url {
                ShareLink(item: url)
            }
            Divider()
            Button("Downloads", systemImage: "arrow.down.circle") { browser.showsDownloads = true }
            Button("Bookmarks and History", systemImage: "books.vertical") { browser.showsLibrary = true }
            Divider()
            Button("Settings", systemImage: "gearshape") { browser.showsSettings = true }
        } label: {
            Image(systemName: "ellipsis")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
    }
}
