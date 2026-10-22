import SwiftUI
import QuickLook

/// The sidebar in wide windows. It shows Bookmarks, History and Downloads; tabs stay in the
/// navigation bar unless the person turns on Show tabs in sidebar.
struct BrowserSidebar: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var preferences: BrowserPreferences
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var history: HistoryStore
    @ObservedObject var downloadCenter: DownloadCenter
    @AppStorage("sidebarLibrarySection") private var section = LibrarySection.bookmarks
    @State private var closingScope: TabCloseScope?
    @State private var query = ""
    @State private var searchPresented = false
    @State private var previewURL: URL?

    enum LibrarySection: String, CaseIterable, Identifiable {
        case bookmarks, history, downloads
        var id: String { rawValue }
        var title: String {
            switch self {
            case .bookmarks: return "Bookmarks"
            case .history: return "History"
            case .downloads: return "Downloads"
            }
        }
    }

    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var visibleTabs: [BrowserTab] {
        browser.tabs.filter { matchesTabSearch($0, query: query) }
    }

    var body: some View {
        List {
            if preferences.showsTabsInSidebar {
                Section {
                    ForEach(visibleTabs) { tab in
                        SidebarTabRow(tab: tab)
                            .listRowBackground(browser.selectedTabID == tab.id ? Color.accentColor.opacity(0.12) : Color.clear)
                            .swipeActions {
                                Button(role: .destructive) { browser.close(tab) } label: {
                                    Label("Close", systemImage: "xmark")
                                }
                            }
                            .contextMenu {
                                Button("Duplicate", systemImage: "plus.square.on.square") { browser.duplicate(tab) }
                                Button("Close", systemImage: "xmark", role: .destructive) { browser.close(tab) }
                            }
                    }
                    .onMove(perform: browser.moveTabs)
                    .moveDisabled(!term.isEmpty)
                } header: {
                    Text("Tabs")
                }
            }
            Section {
                Picker("Library", selection: $section) {
                    ForEach(LibrarySection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("sidebarLibraryPicker")
                libraryRows
            } header: {
                if preferences.showsTabsInSidebar { Text("Library") }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Library")
        .searchable(text: $query, isPresented: $searchPresented,
                    prompt: preferences.showsTabsInSidebar ? "Search tabs and library" : "Search library")
        .quickLookPreview($previewURL)
        .modifier(TabClosingConfirmation(scope: $closingScope))
        .toolbar {
            if preferences.showsTabsInSidebar {
                ToolbarItem(placement: .primaryAction) { TabManagementMenu(scope: $closingScope) }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Tab", systemImage: "plus") { browser.newTab() }
                    Button("New Private Tab", systemImage: "hand.raised.fill") { browser.newTab(isPrivate: true) }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("New Tab Options")
            }
        }
        .accessibilityIdentifier("browserSidebar")
    }

    @ViewBuilder private var libraryRows: some View {
        switch section {
        case .bookmarks:
            let items = bookmarks.items.filter { $0.matchesSearch(term) }
            if items.isEmpty {
                emptyRow(term.isEmpty ? "Bookmark a page from More, then Saved Content." : "No matching bookmarks.")
            }
            ForEach(items) { siteRow($0, symbol: "bookmark.fill") }
            manageRow("Edit Bookmarks…") { browser.showsLibrary = true }
        case .history:
            let items = history.items.filter { $0.matchesSearch(term) }
            if items.isEmpty {
                emptyRow(!term.isEmpty ? "No matching history." :
                            (preferences.savesHistory ? "Pages you visit will appear here." : "History is off. You can turn it on in Settings."))
            }
            ForEach(items.prefix(100)) { siteRow($0, symbol: "clock") }
            manageRow("Manage History…") { browser.showsLibrary = true }
        case .downloads:
            let items = downloadCenter.items.filter { term.isEmpty || $0.filename.localizedCaseInsensitiveContains(term) }
            if items.isEmpty {
                emptyRow(term.isEmpty ? "Files downloaded from websites will appear here." : "No matching downloads.")
            }
            ForEach(items) { item in
                Button {
                    if item.state == .finished { previewURL = item.destination } else { browser.showsDownloads = true }
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.filename).lineLimit(1).truncationMode(.middle)
                            Text(item.failureReason ?? item.state.rawValue).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: item.state == .finished ? "doc" : item.state == .failed ? "exclamationmark.triangle" : "arrow.down.circle")
                    }
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
            manageRow("Manage Downloads…") { browser.showsDownloads = true }
        }
    }

    private func siteRow(_ site: SavedSite, symbol: String) -> some View {
        Button {
            if let url = site.url { browser.open(url) }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(site.title).lineLimit(1)
                    Text(site.url?.host ?? site.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            } icon: {
                Image(systemName: symbol).foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contextMenu {
            if let url = site.url {
                Button("Open in New Tab", systemImage: "plus.square.on.square") {
                    browser.openInNewTab(url, isPrivate: browser.selectedTab?.isPrivate == true)
                }
                Button("Open in New Private Tab", systemImage: "hand.raised.fill") { browser.openInNewTab(url, isPrivate: true) }
                ShareLink(item: url)
            }
        }
    }

    private func emptyRow(_ message: String) -> some View {
        Text(message).font(.callout).foregroundStyle(.secondary)
    }

    private func manageRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).frame(minHeight: 44)
    }
}
