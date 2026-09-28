import SwiftUI

struct BrowserToolbar: View {
    @EnvironmentObject private var browser: BrowserStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var addressFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
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

            HStack(spacing: 8) {
                Image(systemName: browser.selectedTab?.isPrivate == true ? "hand.raised.fill" : "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search or enter address", text: $browser.addressDraft)
                    .accessibilityIdentifier("addressField")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .focused($addressFocused)
                    .submitLabel(.go)
                    .onSubmit(browser.navigate)
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

            if horizontalSizeClass == .compact {
                Button { browser.showsTabs = true } label: {
                    Image(systemName: "square.on.square")
                        .overlay(alignment: .center) {
                            Text("\(browser.tabs.count)").font(.system(size: 8, weight: .bold))
                        }
                }
                .accessibilityLabel("Tabs")
                .accessibilityValue("\(browser.tabs.count) open")
                .frame(minWidth: 44, minHeight: 44)
            }

            if browser.selectedTab?.url != nil, browser.selectedTab?.isPrivate != true {
                Button { browser.toggleBookmark() } label: {
                    Image(systemName: browser.bookmarks.contains(browser.selectedTab?.url) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(browser.bookmarks.contains(browser.selectedTab?.url) ? "Remove Bookmark" : "Add Bookmark")
                .frame(minWidth: 44, minHeight: 44)
            }

            Menu {
                Button("New Tab", systemImage: "plus") { browser.newTab() }
                Button("New Private Tab", systemImage: "hand.raised.fill") { browser.newTab(isPrivate: true) }
                Button("Reopen Closed Tab", systemImage: "arrow.uturn.backward") {
                    browser.reopenLastClosedTab()
                }
                .disabled(browser.recentlyClosed.isEmpty)
                Divider()
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
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

private extension View {
    @ViewBuilder
    func acuteGlass(cornerRadius: CGFloat) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.14), lineWidth: 0.5)
                }
        }
#else
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.14), lineWidth: 0.5)
            }
#endif
    }
}
