import SwiftUI

struct BookmarkEditor: View {
    @ObservedObject var bookmarks: BookmarkStore
    let item: SavedSite
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var address: String
    @State private var failedToSave = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case title, address }

    init(bookmarks: BookmarkStore, item: SavedSite) {
        self.bookmarks = bookmarks
        self.item = item
        _title = State(initialValue: item.title)
        _address = State(initialValue: item.address)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .address }
                        .accessibilityIdentifier("bookmarkTitle")
                }
                Section {
                    HStack {
                        TextField("Website address", text: $address)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .focused($focusedField, equals: .address)
                            .accessibilityIdentifier("bookmarkAddress")
                        Button {
                            address = ""
                            focusedField = .address
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .disabled(address.isEmpty)
                        .accessibilityLabel("Clear bookmark address")
                        .accessibilityIdentifier("clearBookmarkAddress")
                    }
                } header: { Text("Address") } footer: {
                    if BookmarkStore.validatedURL(address) == nil {
                        Text("Enter an HTTP or HTTPS website address.")
                    }
                }
            }
            .navigationTitle("Edit Bookmark")
            .navigationBarTitleDisplayMode(.inline)
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
