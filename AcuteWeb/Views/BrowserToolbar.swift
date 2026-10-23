import SwiftUI
import WebKit

struct BrowserToolbar: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @ObservedObject var preferences: BrowserPreferences
    /// Rail mode moves Back, Forward, Tabs and More to `NavigationRail`.
    var mode: BrowserChromeMode = .compactRow(atBottom: false)
    /// Off when the sidebar lists tabs, so other tabs leave the navigation bar.
    var showsOtherTabs = true
    /// Keeps the row on the trailing side of a vertical fold.
    var leadingClearance: CGFloat = 0
    /// Set when Back, Forward, Tabs and More are shown elsewhere, such as the tabletop control deck.
    var hidesNavigationControls = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var addressFocused: Bool
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 44
    @State private var controlsExpanded = false
    @State private var addressSelection: TextSelection?
    @State private var submittedAddress = false

    private var isCompactWidth: Bool { horizontalSizeClass != .regular }
    private var navigationControlsElsewhere: Bool { hidesNavigationControls || mode.railEdge != nil }
    private var isCondensed: Bool {
        isCompactWidth && preferences.condensesPhoneControls && tab.hasRenderedPage && !tab.isLoading
            && tab.navigationError == nil && !controlsExpanded && !addressFocused && !browser.showsFindBar
    }

    var body: some View {
        AcuteGlassContainer(spacing: 4) {
            GeometryReader { row in
                HStack(spacing: 6) {
                    if !navigationControlsElsewhere {
                        navigationButtons.acuteGlass(cornerRadius: rowHeight / 2)
                    }
                    tabCapsules.frame(maxWidth: .infinity)
                    if navigationControlsElsewhere {
                        if addressFocused {
                            Button("Done") {
                                addressFocused = false
                                controlsExpanded = false
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: rowHeight)
                            .acuteGlass(cornerRadius: rowHeight / 2)
                            .accessibilityIdentifier("finishAddressEditing")
                        }
                    } else {
                        if !addressFocused && (row.size.width >= 360 || !tab.canGoForward) {
                            TabsOverviewButton(tab: tab, height: rowHeight).acuteGlass(cornerRadius: rowHeight / 2)
                        }
                        BrowserMoreMenu(tab: tab, height: rowHeight, doneEditing: controlsExpanded ? {
                            addressFocused = false
                            controlsExpanded = false
                        } : nil)
                        .acuteGlass(cornerRadius: rowHeight / 2)
                    }
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
            get: { browser.addressInputError != nil },
            // SwiftUI sets this while updating views as the alert closes, so publish the change afterwards.
            set: { presented in if !presented { DispatchQueue.main.async { browser.addressInputError = nil } } }
        )) {
            Button("OK") { browser.addressInputError = nil }
        } message: {
            Text(browser.addressInputError ?? "")
        }
        .buttonStyle(.plain)
        .font(.body.weight(.medium))
        // Like system bars, the row stops growing at the largest standard size so its buttons never
        // overlap; touch and hold a button to see it in the large content viewer.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.leading, 8 + leadingClearance)
        .padding(.trailing, 8)
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
                                    .frame(width: max(100, min(isCompactWidth ? viewport.size.width : 440,
                                        viewport.size.width - (!addressFocused && browser.tabs.count > 1 ? 18 : 0))))
                                    .id(candidate.id)
                            } else if showsOtherTabs {
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
                // The full prompt does not fit beside the buttons at accessibility sizes.
                TextField(dynamicTypeSize.isAccessibilitySize ? "Search" : "Search or enter address",
                          text: $browser.addressDraft, selection: $addressSelection)
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
                    .accessibilityShowsLargeContentViewer()
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
            HistoryButton(tab: tab, direction: .back, height: rowHeight)
            if tab.canGoForward {
                HistoryButton(tab: tab, direction: .forward, height: rowHeight)
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
        .accessibilityShowsLargeContentViewer()
        .accessibilityIdentifier("pageLoadControl")
        .disabled(!tab.isLoading && tab.url == nil && tab.lastRequestedURL == nil)
    }

}
