import SwiftUI
import QuickLook

struct DownloadsView: View {
    @ObservedObject var downloadCenter: DownloadCenter
    @State private var previewURL: URL?
    @State private var query = ""
    @State private var searchPresented = false
    @State private var pendingDelete: DownloadItem?
    @State private var deletionError: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private var filteredItems: [DownloadItem] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return downloadCenter.items.filter { term.isEmpty || $0.filename.localizedCaseInsensitiveContains(term) }
    }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filteredItems.isEmpty {
                    SearchRecoveryView(query: $query, searchPresented: $searchPresented, identifier: "clearDownloadsSearch")
                } else if downloadCenter.items.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Files downloaded from websites will appear here.")
                    )
                } else {
                    List(filteredItems) { item in
                        rowLayout {
                            HStack(spacing: 12) {
                                ZStack {
                                    if item.state == .downloading {
                                        ProgressView().tint(.accentColor)
                                    } else {
                                        Image(systemName: symbol(for: item.state))
                                            .foregroundStyle(color(for: item.state))
                                            .font(.title3)
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .background(color(for: item.state).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.filename).font(.body.weight(.medium)).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                                        .truncationMode(.middle)
                                    Text(item.failureReason ?? item.state.rawValue)
                                        .font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            rowLayout {
                                if item.state == .downloading {
                                    Button { downloadCenter.cancel(item) } label: {
                                        actionLabel("Cancel", symbol: "xmark.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Cancel \(item.filename)")
                                }
                                if item.state == .finished, let destination = item.destination {
                                    Button {
                                        previewURL = destination
                                    } label: {
                                        actionLabel("Preview", symbol: "doc.text.magnifyingglass")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Preview \(item.filename)")
                                    ShareLink(item: destination) {
                                        actionLabel("Share", symbol: "square.and.arrow.up")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Share \(item.filename)")
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .swipeActions {
                            if item.state == .finished {
                                Button("Delete", role: .destructive) { pendingDelete = item }
                            } else if item.state == .failed {
                                Button("Remove", role: .destructive) { remove(item) }
                            }
                        }
                        .contextMenu {
                            if item.state == .finished {
                                Button("Delete File", systemImage: "trash", role: .destructive) { pendingDelete = item }
                            } else if item.state == .downloading {
                                Button("Cancel Download", systemImage: "xmark.circle") { downloadCenter.cancel(item) }
                            } else {
                                Button("Remove from List", systemImage: "trash") { remove(item) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, isPresented: $searchPresented, prompt: "Search downloads")
            .scrollDismissesKeyboard(.immediately)
            .confirmationDialog("Delete Download?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                if let item = pendingDelete {
                    Button("Delete File", role: .destructive) { remove(item); pendingDelete = nil }
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This removes the downloaded file from this device.")
            }
            .alert("Unable to Delete Download", isPresented: Binding(
                get: { deletionError != nil }, set: { if !$0 { deletionError = nil } }
            )) {
                Button("OK", role: .cancel) { deletionError = nil }
            } message: { Text(deletionError ?? "") }
            .quickLookPreview($previewURL)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetDoneButton { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: String, symbol: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Label(title, systemImage: symbol)
            } else {
                Image(systemName: symbol)
            }
        }
        .frame(minWidth: 44, minHeight: 44, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
        .contentShape(Rectangle())
    }

    private func remove(_ item: DownloadItem) {
        do {
            if previewURL == item.destination { previewURL = nil }
            try downloadCenter.remove(item)
        } catch { deletionError = error.localizedDescription }
    }

    private func symbol(for state: DownloadState) -> String {
        switch state {
        case .downloading: return "arrow.down.circle"
        case .finished: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for state: DownloadState) -> Color {
        switch state {
        case .downloading: return .accentColor
        case .finished: return .green
        case .failed: return .orange
        }
    }
}
