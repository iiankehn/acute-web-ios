import SwiftUI
import QuickLook

struct DownloadsView: View {
    @ObservedObject var downloadCenter: DownloadCenter
    @State private var previewURL: URL?
    @State private var query = ""
    @State private var pendingDelete: DownloadItem?
    @State private var deletionError: String?

    private var filteredItems: [DownloadItem] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return downloadCenter.items.filter { term.isEmpty || $0.filename.localizedCaseInsensitiveContains(term) }
    }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if downloadCenter.items.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Files downloaded from websites will appear here.")
                    )
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(filteredItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: symbol(for: item.state))
                                .foregroundStyle(color(for: item.state))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.filename).lineLimit(1)
                                Text(item.failureReason ?? item.state.rawValue)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            if item.state == .downloading {
                                Button { downloadCenter.cancel(item) } label: {
                                    Image(systemName: "xmark.circle").frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Cancel \(item.filename)")
                            }
                            if item.state == .finished, let destination = item.destination {
                                Button {
                                    previewURL = destination
                                } label: {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Preview \(item.filename)")
                                ShareLink(item: destination) {
                                    Image(systemName: "square.and.arrow.up")
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Share \(item.filename)")
                            }
                        }
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
                }
            }
            .navigationTitle("Downloads")
            .searchable(text: $query, prompt: "Search downloads")
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
                    Button("Done") { dismiss() }
                }
            }
        }
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
        case .downloading: return .cyan
        case .finished: return .green
        case .failed: return .orange
        }
    }
}
