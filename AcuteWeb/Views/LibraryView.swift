import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library", selection: $selection) {
                    Text("Bookmarks").tag(0)
                    Text("History").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selection == 0 { bookmarksList } else { historyList }
            }
            .navigationTitle("Library")
            .searchable(text: $query, prompt: "Search titles or addresses")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                if selection == 1 && !history.items.isEmpty {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Clear", role: .destructive) { history.clear() }
                    }
                }
            }
        }
    }

    @ViewBuilder private var bookmarksList: some View {
        if bookmarks.items.isEmpty {
            ContentUnavailableView("No Bookmarks", systemImage: "bookmark", description: Text("Save a page with the bookmark button in the toolbar."))
        } else if filtered(bookmarks.items).isEmpty {
            noSearchResults
        } else {
            List(filtered(bookmarks.items)) { item in siteRow(item) { bookmarks.remove(item) } }
        }
    }

    @ViewBuilder private var historyList: some View {
        if history.items.isEmpty {
            ContentUnavailableView(
                "No History",
                systemImage: "clock.arrow.circlepath",
                description: Text(browser.preferences.savesHistory ? "Pages you visit will appear here." : "History is off by default. You can enable it in Settings.")
            )
        } else if filtered(history.items).isEmpty {
            noSearchResults
        } else {
            List(filtered(history.items)) { item in siteRow(item) { history.remove(item) } }
        }
    }

    private var noSearchResults: some View {
        ContentUnavailableView.search(text: query)
    }

    private func filtered(_ items: [SavedSite]) -> [SavedSite] {
        items.filter { $0.matchesSearch(query) }
    }

    private func siteRow(_ item: SavedSite, remove: @escaping () -> Void) -> some View {
        Button {
            if let url = item.url { browser.open(url); dismiss() }
        } label: {
            HStack {
                Image(systemName: "globe")
                VStack(alignment: .leading) {
                    Text(item.title).lineLimit(1)
                    Text(item.url?.host ?? item.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
        }
        .swipeActions { Button("Delete", role: .destructive, action: remove) }
        .contextMenu {
            if let url = item.url {
                ShareLink(item: url)
            }
            Button("Delete", systemImage: "trash", role: .destructive, action: remove)
        }
    }
}
