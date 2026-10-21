import SwiftUI
import WebKit

struct BrowserToolbar: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @ObservedObject var preferences: BrowserPreferences
    @FocusState private var addressFocused: Bool
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 9
    @State private var controlsExpanded = false
    @State private var addressSelection: TextSelection?
    @State private var submittedAddress = false

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
        .onChange(of: browser.addressDismissRequest) { _, _ in
            // A chosen suggestion has already started loading; keep its address.
            submittedAddress = addressFocused
            addressFocused = false
            controlsExpanded = false
        }
        .onChange(of: addressFocused) { _, focused in
            browser.isEditingAddress = focused
            if focused {
                controlsExpanded = true
                // Select the whole address so typing replaces it, as in other browsers.
                DispatchQueue.main.async {
                    let draft = browser.addressDraft
                    addressSelection = TextSelection(range: draft.startIndex..<draft.endIndex)
                }
            } else if submittedAddress {
                submittedAddress = false
            } else {
                browser.syncAddressWithPage()
            }
        }
        .onDisappear {
            if addressFocused { browser.isEditingAddress = false }
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
                        securityIndicator
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
                .accessibilityValue("\(tab.title), \(tab.url?.absoluteString ?? ""), \(tab.connectionSecurity.summary)\(tab.isPrivate ? ", private tab" : "")")
                .accessibilityIdentifier("condensedAddress")
                .accessibilityAddTraits(.isSelected)
            } else {
                if !addressFocused && tab.url != nil {
                    securityIndicator.padding(.leading, 12)
                }
                TextField("Search or enter address", text: $browser.addressDraft, selection: $addressSelection)
                    .accessibilityLabel("Search or enter address")
                    .accessibilityIdentifier("addressField")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .focused($addressFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        browser.navigate()
                        submittedAddress = true
                        addressFocused = false
                        controlsExpanded = false
                    }
                    .padding(.leading, !addressFocused && tab.url != nil ? 4 : 12)
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

    /// Connection security stays visible in private tabs; the private mark is shown beside it.
    private var securityIndicator: some View {
        HStack(spacing: 3) {
            if tab.isPrivate {
                Image(systemName: "hand.raised.fill").font(.caption2)
            }
            Image(systemName: tab.connectionSecurity.symbol).font(.caption)
                .foregroundStyle(tab.connectionSecurity == .secure || tab.connectionSecurity == .none ? Color.secondary : Color.orange)
            if tab.connectionSecurity == .insecure && isCondensed {
                Text("Not Secure").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.connectionSecurity.summary + (tab.isPrivate ? ", private tab" : ""))
        .accessibilityIdentifier("connectionSecurity")
    }

    private var navigationButtons: some View {
        HStack(spacing: 0) {
            historyButton(title: "Back", symbol: "chevron.backward", items: Array(tab.webView.backForwardList.backList.reversed())) {
                tab.webView.goBack()
            }
            .disabled(!tab.canGoBack)
            if tab.canGoForward {
                historyButton(title: "Forward", symbol: "chevron.forward", items: tab.webView.backForwardList.forwardList) {
                    tab.webView.goForward()
                }
            }
        }
    }

    /// Tap to move one page; touch and hold to choose from the tab's history.
    private func historyButton(title: String, symbol: String, items: [WKBackForwardListItem],
                               action: @escaping () -> Void) -> some View {
        Menu {
            ForEach(Array(items.prefix(15).enumerated()), id: \.offset) { _, item in
                Button(item.title?.isEmpty == false ? item.title! : (item.url.host ?? item.url.absoluteString)) {
                    tab.webView.go(to: item)
                }
            }
        } label: {
            Image(systemName: symbol).frame(width: 44, height: rowHeight)
                .contentShape(Rectangle())
        } primaryAction: {
            action()
        }
        .menuIndicator(.hidden)
        .accessibilityLabel(title)
        .accessibilityHint("Touch and hold for history")
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
            Image(systemName: "square.on.square")
                .overlay {
                    Text(browser.tabs.count > 99 ? "∞" : "\(browser.tabs.count)")
                        .font(.system(size: min(badgeSize, 13), weight: .bold))
                        .minimumScaleFactor(0.6)
                        .allowsHitTesting(false)
                }
                .frame(width: 44, height: rowHeight).contentShape(Rectangle())
        }
        .accessibilityLabel("Tabs").accessibilityValue("\(browser.tabs.count) open")
    }

    private var moreMenu: some View {
        Menu {
            Menu("Tab Management", systemImage: "square.on.square") {
                Button("New Tab", systemImage: "plus") { browser.newTab() }
                Button("New Private Tab", systemImage: "hand.raised.fill") { browser.newTab(isPrivate: true) }
                Button("Show All Tabs", systemImage: "square.on.square") {
                    tab.captureSnapshot(); browser.showsTabs = true
                }
                Button("Reopen Closed Tab", systemImage: "arrow.uturn.backward") { browser.reopenLastClosedTab() }
                    .disabled(browser.recentlyClosed.isEmpty)
            }
            Menu("Page Tools", systemImage: "doc.text") {
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
