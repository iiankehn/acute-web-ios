import SwiftUI

struct DownloadsView: View {
    @ObservedObject var downloadCenter: DownloadCenter
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
                } else {
                    List(downloadCenter.items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: symbol(for: item.state))
                                .foregroundStyle(color(for: item.state))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.filename).lineLimit(1)
                                Text(item.failureReason ?? item.state.rawValue)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            if item.state == .finished, let destination = item.destination {
                                ShareLink(item: destination) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
