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
    private var downloads: [ObjectIdentifier: WKDownload] = [:]
    private var temporaryDestinations: [ObjectIdentifier: URL] = [:]
    private var itemIDs: [ObjectIdentifier: UUID] = [:]
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        super.init()
        // Downloads interrupted by a previous process are never exposed as completed files.
        try? FileManager.default.removeItem(at: self.directory.appendingPathComponent(".in-progress", isDirectory: true))
        recoverSavedFiles()
    }

    private func recoverSavedFiles() {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
        ) else { return }
        let savedFiles = files.compactMap { url -> (URL, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { return nil }
            return (url, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.1 > $1.1 }
        items = savedFiles.map {
            DownloadItem(id: UUID(), filename: $0.0.lastPathComponent, destination: $0.0, state: .finished)
        }
    }

    func register(_ download: WKDownload) {
        downloads[ObjectIdentifier(download)] = download
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
            let stagingDirectory = directory.appendingPathComponent(".in-progress", isDirectory: true)
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            let temporaryURL = stagingDirectory.appendingPathComponent(UUID().uuidString)
            temporaryDestinations[ObjectIdentifier(download)] = temporaryURL
            let id = UUID()
            itemIDs[ObjectIdentifier(download)] = id
            items.insert(
                DownloadItem(id: id, filename: destination.lastPathComponent, destination: destination, state: .downloading),
                at: 0
            )
            completionHandler(temporaryURL)
        } catch {
            downloads.removeValue(forKey: ObjectIdentifier(download))
            let filename = uniqueDestination(for: suggestedFilename, in: directory).lastPathComponent
            items.insert(DownloadItem(id: UUID(), filename: filename, destination: nil,
                                      state: .failed, failureReason: error.localizedDescription), at: 0)
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        defer {
            downloads.removeValue(forKey: key)
            itemIDs.removeValue(forKey: key)
            temporaryDestinations.removeValue(forKey: key)
        }
        guard let temporaryURL = temporaryDestinations[key], let id = itemIDs[key],
              let item = items.first(where: { $0.id == id }), let destination = item.destination else { return }
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            update(download) { $0.state = .finished }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            update(download) {
                $0.state = .failed
                $0.failureReason = error.localizedDescription
            }
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let key = ObjectIdentifier(download)
        if let temporaryURL = temporaryDestinations.removeValue(forKey: key) {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        update(download) {
            $0.state = .failed
            $0.failureReason = error.localizedDescription
        }
        itemIDs.removeValue(forKey: key)
        downloads.removeValue(forKey: key)
    }

    func cancel(_ item: DownloadItem) {
        guard item.state == .downloading,
              let key = itemIDs.first(where: { $0.value == item.id })?.key,
              let download = downloads[key] else { return }
        // Remove delegate bookkeeping before cancellation can call back.
        itemIDs.removeValue(forKey: key)
        downloads.removeValue(forKey: key)
        let temporaryURL = temporaryDestinations.removeValue(forKey: key)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].state = .failed
            items[index].failureReason = "Cancelled"
        }
        download.cancel { _ in
            if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
        }
    }

    func remove(_ item: DownloadItem) throws {
        guard item.state != .downloading else { return }
        if item.state == .finished, let destination = item.destination {
            guard destination.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path else {
                throw CocoaError(.fileWriteNoPermission)
            }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
        }
        items.removeAll { $0.id == item.id }
    }

    private func update(_ download: WKDownload, change: (inout DownloadItem) -> Void) {
        guard let id = itemIDs[ObjectIdentifier(download)],
              let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    private func downloadsDirectory() throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func uniqueDestination(for filename: String, in directory: URL) -> URL {
        let cleaned = filename.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = cleaned.isEmpty || cleaned == "." || cleaned == ".." || cleaned.hasPrefix(".")
            ? "Download" : cleaned
        var candidate = directory.appendingPathComponent(safeName)
        let extensionName = candidate.pathExtension
        let stem = candidate.deletingPathExtension().lastPathComponent
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) || items.contains(where: { $0.destination == candidate }) {
            let suffix = extensionName.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(extensionName)"
            candidate = directory.appendingPathComponent(suffix)
            counter += 1
        }
        return candidate
    }
}
