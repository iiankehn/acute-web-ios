import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection = 0
    @State private var query = ""
    @State private var searchPresented = false
    @State private var editingBookmark: SavedSite?
    @State private var confirmsHistoryDeletion = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                libraryPicker.padding()

                if selection == 0 { bookmarksList } else { historyList }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(item: $editingBookmark) { item in
                BookmarkEditor(bookmarks: bookmarks, item: item)
            }
            .onReceive(bookmarks.objectWillChange) { _ in browser.objectWillChange.send() }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Clear Saved History?", isPresented: $confirmsHistoryDeletion) {
                Button("Clear Saved History", role: .destructive) { history.clear() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all saved visits from this device, including visits outside the current search results.")
            }
            .searchable(text: $query, isPresented: $searchPresented, prompt: "Search titles or addresses")
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetDoneButton { dismiss() }
                }
                if selection == 1 && !history.items.isEmpty {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Clear", role: .destructive) { confirmsHistoryDeletion = true }
                    }
                }
            }
        }
    }

    private var libraryChoices: some View {
        Picker("Library", selection: $selection) {
            Text("Bookmarks").tag(0)
            Text("History").tag(1)
        }
    }

    @ViewBuilder private var libraryPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            libraryChoices.pickerStyle(.menu)
        } else {
            libraryChoices.pickerStyle(.segmented)
        }
    }

    @ViewBuilder private var bookmarksList: some View {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filtered(bookmarks.items).isEmpty {
            noSearchResults
        } else if bookmarks.items.isEmpty {
            ContentUnavailableView("No Bookmarks", systemImage: "bookmark", description: Text("Open More, then Library, to bookmark the current page."))
        } else {
            List {
                Section {
                    ForEach(filtered(bookmarks.items)) { item in
                        siteRow(item, isBookmark: true) { bookmarks.remove(item) }
                    }
                } header: { Text("\(filtered(bookmarks.items).count) saved") }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder private var historyList: some View {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filtered(history.items).isEmpty {
            noSearchResults
        } else if history.items.isEmpty {
            ContentUnavailableView(
                "No History",
                systemImage: "clock.arrow.circlepath",
                description: Text(browser.preferences.savesHistory ? "Pages you visit will appear here." : "History is off by default. You can enable it in Settings.")
            )
        } else {
            List {
                Section {
                    ForEach(filtered(history.items)) { item in
                        siteRow(item, isBookmark: false) { history.remove(item) }
                    }
                } header: { Text("\(filtered(history.items).count) visits") }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var noSearchResults: some View {
        SearchRecoveryView(query: $query, searchPresented: $searchPresented, identifier: "clearLibrarySearch")
    }

    private func filtered(_ items: [SavedSite]) -> [SavedSite] {
        items.filter { $0.matchesSearch(query) }
    }

    private func siteRow(_ item: SavedSite, isBookmark: Bool, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button {
                if let url = item.url { browser.open(url); dismiss() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isBookmark ? "bookmark.fill" : "clock")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        Text(item.address).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(minHeight: 44)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            if isBookmark {
                Button {
                    searchPresented = false
                    editingBookmark = item
                } label: {
                    Image(systemName: "pencil")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Edit \(item.title)")
                .accessibilityIdentifier("editBookmark_\(item.id.uuidString)")
            }
        }
        .swipeActions { Button("Delete", role: .destructive, action: remove) }
        .contextMenu {
            if let url = item.url {
                Button("Open in New Tab", systemImage: "plus.square.on.square") {
                    browser.openInNewTab(url, isPrivate: browser.selectedTab?.isPrivate == true)
                    dismiss()
                }
                Button("Open in New Private Tab", systemImage: "hand.raised.fill") {
                    browser.openInNewTab(url, isPrivate: true)
                    dismiss()
                }
                ShareLink(item: url)
            }
            if isBookmark {
                Button("Edit Bookmark", systemImage: "pencil") {
                    searchPresented = false
                    editingBookmark = item
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive, action: remove)
        }
    }
}
