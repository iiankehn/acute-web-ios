import SwiftUI

struct BookmarkEditor: View {
    @ObservedObject var bookmarks: BookmarkStore
    let item: SavedSite
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var address: String
    @State private var failedToSave = false

    init(bookmarks: BookmarkStore, item: SavedSite) {
        self.bookmarks = bookmarks
        self.item = item
        _title = State(initialValue: item.title)
        _address = State(initialValue: item.address)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bookmark") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("bookmarkTitle")
                    TextField("Website address", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier("bookmarkAddress")
                }
                if BookmarkStore.validatedURL(address) == nil {
                    Text("Enter an HTTP or HTTPS website address.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Bookmark")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if bookmarks.update(item, title: title, address: address) { dismiss() }
                        else { failedToSave = true }
                    }
                    .disabled(BookmarkStore.validatedURL(address) == nil)
                }
            }
            .alert("Unable to Save Bookmark", isPresented: $failedToSave) {
                Button("OK", role: .cancel) {}
            } message: { Text("The bookmark may have been removed. Close this editor and try again.") }
        }
    }
}
