import SwiftUI

struct BrowserToolbar: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @ObservedObject var preferences: BrowserPreferences
    @FocusState private var addressFocused: Bool
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 44
    @State private var controlsExpanded = false

    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    private var isCondensed: Bool {
        isPhone && preferences.condensesPhoneControls && tab.hasRenderedPage && !tab.isLoading
            && tab.navigationError == nil && !controlsExpanded && !addressFocused && !browser.showsFindBar
    }

    var body: some View {
        AcuteGlassContainer(spacing: 4) {
            GeometryReader { row in
                HStack(spacing: 6) {
                    navigationButtons.acuteGlass(cornerRadius: rowHeight / 2)
                    tabCapsules.frame(maxWidth: .infinity)
                    if !addressFocused && (row.size.width >= 360 || !tab.canGoForward) {
                        tabsButton.acuteGlass(cornerRadius: rowHeight / 2)
                            .accessibilityElement(children: .ignore)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("Tabs")
                            .accessibilityValue("\(browser.tabs.count) open")
                            .accessibilityIdentifier("tabsOverview")
                    }
                    moreMenu.acuteGlass(cornerRadius: rowHeight / 2)
                }
            }
            .frame(height: max(44, rowHeight))
        }
        .onChange(of: tab.hasRenderedPage) { _, rendered in
            if rendered { controlsExpanded = false }
        }
        .onChange(of: browser.addressFocusRequest) { _, _ in
            controlsExpanded = true
            addressFocused = true
        }
        .onChange(of: addressFocused) { _, focused in
            if focused { controlsExpanded = true }
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
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var tabCapsules: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(browser.tabs) { candidate in
                            if candidate.id == tab.id {
                                currentTabCapsule
                                    .frame(width: max(100, min(isPhone ? viewport.size.width : 440,
                                        viewport.size.width - (!addressFocused && browser.tabs.count > 1 ? 18 : 0))))
                                    .id(candidate.id)
                            } else {
                                NavigationTabCapsule(tab: candidate, height: rowHeight).id(candidate.id)
                            }
                        }
                        Button { browser.newTab() } label: {
                            Image(systemName: "plus").frame(width: 44, height: rowHeight)
                                .contentShape(Rectangle())
                        }
                        .acuteGlass(cornerRadius: rowHeight / 2)
                        .accessibilityLabel("Add Tab")
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("navigationTabCapsules")
                .onAppear { proxy.scrollTo(tab.id, anchor: .leading) }
                .onChange(of: addressFocused) { _, _ in proxy.scrollTo(tab.id, anchor: .leading) }
                .onChange(of: viewport.size.width) { _, _ in proxy.scrollTo(tab.id, anchor: .leading) }
            }
        }
    }

    private var currentTabCapsule: some View {
        HStack(spacing: 0) {
            if isCondensed {
                Button {
                    controlsExpanded = true
                    addressFocused = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: addressSymbol).font(.caption).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preferences.showsCompactPageTitle ? tab.title : (tab.url?.host ?? tab.title))
                                .font(.subheadline.weight(.semibold)).lineLimit(1)
                            if preferences.showsCompactPageTitle, let host = tab.url?.host {
                                Text(host).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, minHeight: rowHeight)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Edit Address")
                .accessibilityValue("\(tab.title), \(tab.url?.absoluteString ?? "")")
                .accessibilityIdentifier("condensedAddress")
                .accessibilityAddTraits(.isSelected)
            } else {
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
                        controlsExpanded = false
                        browser.navigate()
                    }
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, minHeight: rowHeight)
                if addressFocused {
                    Button {
                        browser.addressDraft = ""
                        browser.addressInputError = nil
                        addressFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            .frame(width: 44, height: rowHeight).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Clear Address")
                    .accessibilityIdentifier("clearAddress")
                    .disabled(browser.addressDraft.isEmpty)
                }
            }
            pageLoadButton
        }
        .frame(minHeight: rowHeight)
        .acuteGlass(cornerRadius: rowHeight / 2)
        .overlay {
            RoundedRectangle(cornerRadius: rowHeight / 2)
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            if tab.isLoading {
                ProgressView(value: tab.estimatedProgress).progressViewStyle(.linear).tint(.accentColor)
                    .padding(.horizontal, 18).padding(.bottom, 3).allowsHitTesting(false)
                    .accessibilityLabel("Loading page").accessibilityIdentifier("addressLoadingProgress")
            }
        }
    }

    private var addressSymbol: String {
        if tab.isPrivate { return "hand.raised.fill" }
        return tab.url?.scheme?.lowercased() == "https" ? "lock.fill" : "globe"
    }

    private var navigationButtons: some View {
        HStack(spacing: 0) {
            Button { tab.webView.goBack() } label: {
                Image(systemName: "chevron.backward").frame(width: 44, height: rowHeight)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back").disabled(!tab.canGoBack)
            if tab.canGoForward {
                Button { tab.webView.goForward() } label: {
                    Image(systemName: "chevron.forward").frame(width: 44, height: rowHeight)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Forward")
            }
        }
    }

    private var pageLoadButton: some View {
        Button {
            if tab.isLoading { tab.webView.stopLoading() }
            else if tab.navigationError != nil { browser.retryNavigation() }
            else { tab.webView.reload() }
        } label: {
            Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                .frame(width: 44, height: rowHeight).contentShape(Rectangle())
        }
        .accessibilityLabel(tab.isLoading ? "Stop" : "Reload")
        .accessibilityIdentifier("pageLoadControl")
        .disabled(!tab.isLoading && tab.url == nil && tab.lastRequestedURL == nil)
    }

    private var tabsButton: some View {
        Button {
            tab.captureSnapshot()
            browser.showsTabs = true
        } label: {
            ZStack {
                Image(systemName: "square.on.square")
                Text("\(browser.tabs.count)").font(.caption2)
                    .allowsHitTesting(false).accessibilityHidden(true)
                    .accessibilityIdentifier("tabCountDecoration")
            }
            .frame(width: 44, height: rowHeight).contentShape(Rectangle())
        }
    }

    private var moreMenu: some View {
        Menu {
            Menu("Tabs", systemImage: "square.on.square") {
                Button("New Tab", systemImage: "plus") { browser.newTab() }
                Button("New Private Tab", systemImage: "hand.raised.fill") { browser.newTab(isPrivate: true) }
                Button("Show All Tabs", systemImage: "square.on.square") {
                    tab.captureSnapshot(); browser.showsTabs = true
                }
                Button("Reopen Closed Tab", systemImage: "arrow.uturn.backward") { browser.reopenLastClosedTab() }
                    .disabled(browser.recentlyClosed.isEmpty)
            }
            .accessibilityIdentifier("moreTabsMenu")
            Menu("Page", systemImage: "doc.text") {
                if controlsExpanded {
                    Button("Done Editing", systemImage: "checkmark") {
                        addressFocused = false
                        controlsExpanded = false
                    }
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
            .accessibilityIdentifier("morePageMenu")
            Menu("Library", systemImage: "books.vertical") {
                Button(browser.bookmarks.contains(tab.url) ? "Remove Bookmark" : "Add Bookmark", systemImage: "bookmark") {
                    browser.toggleBookmark()
                }
                .disabled(tab.isPrivate || tab.url.flatMap { WebAddress.url($0.absoluteString, allowMissingScheme: false) } == nil)
                Button("Bookmarks and History", systemImage: "books.vertical") { browser.showsLibrary = true }
                Button("Downloads", systemImage: "arrow.down.circle") { browser.showsDownloads = true }
            }
            .accessibilityIdentifier("moreLibraryMenu")
            Menu("Privacy", systemImage: "shield.lefthalf.filled") {
                Button("Site Privacy", systemImage: "shield.lefthalf.filled") { browser.showsSitePrivacy = true }
                    .disabled(tab.url == nil)
            }
            .accessibilityIdentifier("morePrivacyMenu")
            Divider()
            Button("Settings", systemImage: "gearshape") { browser.showsSettings = true }
        } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: rowHeight).contentShape(Rectangle())
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
