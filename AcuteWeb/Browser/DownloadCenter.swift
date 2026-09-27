import Foundation
import WebKit

enum DownloadState: String {
    case downloading = "Downloading"
    case finished = "Ready"
    case failed = "Failed"
}

struct DownloadItem: Identifiable {
    let id: UUID
    let filename: String
    var destination: URL?
    var state: DownloadState
    var failureReason: String?
}

@MainActor
final class DownloadCenter: NSObject, ObservableObject, WKDownloadDelegate {
    @Published private(set) var items: [DownloadItem] = []
    private var itemIDs: [ObjectIdentifier: UUID] = [:]

    func register(_ download: WKDownload) {
        download.delegate = self
    }

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        do {
            let directory = try downloadsDirectory()
            let destination = uniqueDestination(for: suggestedFilename, in: directory)
            let id = UUID()
            itemIDs[ObjectIdentifier(download)] = id
            items.insert(
                DownloadItem(id: id, filename: destination.lastPathComponent, destination: destination, state: .downloading),
                at: 0
            )
            completionHandler(destination)
        } catch {
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        update(download) { $0.state = .finished }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        update(download) {
            $0.state = .failed
            $0.failureReason = error.localizedDescription
        }
    }

    private func update(_ download: WKDownload, change: (inout DownloadItem) -> Void) {
        guard let id = itemIDs[ObjectIdentifier(download)],
              let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    private func downloadsDirectory() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func uniqueDestination(for filename: String, in directory: URL) -> URL {
        let safeName = filename.replacingOccurrences(of: "/", with: "-")
        var candidate = directory.appendingPathComponent(safeName)
        let extensionName = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let suffix = extensionName.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(extensionName)"
            candidate = directory.appendingPathComponent(suffix)
            counter += 1
        }
        return candidate
    }
}
