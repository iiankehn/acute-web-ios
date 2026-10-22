import Foundation
import UIKit
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
    var sourceURL: URL? = nil
    var fractionCompleted: Double? = nil
    var byteCount: Int64? = nil
    var date: Date? = nil
    var canRetry: Bool = false
}

/// A short-lived message shown in the browser window when a download starts or ends.
struct DownloadNotice: Identifiable, Equatable {
    let id = UUID()
    let itemID: UUID
    let filename: String
    let state: DownloadState
}

@MainActor
final class DownloadCenter: NSObject, ObservableObject, WKDownloadDelegate {
    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var notice: DownloadNotice?
    /// Asks the person before saving. Without a handler, downloads are saved (used by isolated tests).
    var confirmDownload: ((WKDownload, String, @escaping (Bool) -> Void) -> Void)?

    private var downloads: [ObjectIdentifier: WKDownload] = [:]
    private var temporaryDestinations: [ObjectIdentifier: URL] = [:]
    private var itemIDs: [ObjectIdentifier: UUID] = [:]
    private var progressObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private var resumable: [UUID: (data: Data, temporaryURL: URL, webView: WeakWebView)] = [:]
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let directory: URL

    private struct WeakWebView {
        weak var webView: WKWebView?
    }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        super.init()
        // Downloads interrupted by a previous process are never exposed as completed files.
        try? FileManager.default.removeItem(at: self.directory.appendingPathComponent(".in-progress", isDirectory: true))
        recoverSavedFiles()
    }

    private func recoverSavedFiles() {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
        ) else { return }
        let savedFiles = files.compactMap { url -> (URL, Date, Int64?)? in
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.fileSize.map(Int64.init))
        }.sorted { $0.1 > $1.1 }
        items = savedFiles.map {
            DownloadItem(id: UUID(), filename: $0.0.lastPathComponent, destination: $0.0, state: .finished,
                         byteCount: $0.2, date: $0.1 == .distantPast ? nil : $0.1)
        }
    }

    var activeCount: Int {
        items.filter { $0.state == .downloading }.count
    }

    func register(_ download: WKDownload) {
        downloads[ObjectIdentifier(download)] = download
        download.delegate = self
    }

    func dismissNotice(_ id: DownloadNotice.ID) {
        if notice?.id == id { notice = nil }
    }

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let key = ObjectIdentifier(download)
        // A resumed download already has a staging file and list entry.
        if itemIDs[key] != nil, let temporaryURL = temporaryDestinations[key] {
            completionHandler(temporaryURL)
            return
        }
        guard let confirmDownload else {
            prepareDestination(for: download, response: response, suggestedFilename: suggestedFilename, completionHandler: completionHandler)
            return
        }
        let filename = uniqueDestination(for: suggestedFilename, in: directory).lastPathComponent
        confirmDownload(download, filename) { [weak self] approved in
            guard let self, approved else {
                self?.downloads.removeValue(forKey: key)
                completionHandler(nil)
                return
            }
            self.prepareDestination(for: download, response: response, suggestedFilename: suggestedFilename,
                                    completionHandler: completionHandler)
        }
    }

    private func prepareDestination(for download: WKDownload, response: URLResponse, suggestedFilename: String,
                                    completionHandler: @escaping (URL?) -> Void) {
        let key = ObjectIdentifier(download)
        do {
            let directory = try downloadsDirectory()
            let destination = uniqueDestination(for: suggestedFilename, in: directory)
            let stagingDirectory = directory.appendingPathComponent(".in-progress", isDirectory: true)
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            let temporaryURL = stagingDirectory.appendingPathComponent(UUID().uuidString)
            temporaryDestinations[key] = temporaryURL
            let id = UUID()
            itemIDs[key] = id
            let expected = response.expectedContentLength
            items.insert(
                DownloadItem(id: id, filename: destination.lastPathComponent, destination: destination, state: .downloading,
                             sourceURL: download.originalRequest?.url ?? response.url,
                             fractionCompleted: expected > 0 ? 0 : nil, byteCount: expected > 0 ? expected : nil),
                at: 0
            )
            observeProgress(of: download)
            notice = DownloadNotice(itemID: id, filename: destination.lastPathComponent, state: .downloading)
            updateBackgroundTask()
            completionHandler(temporaryURL)
        } catch {
            downloads.removeValue(forKey: key)
            let filename = uniqueDestination(for: suggestedFilename, in: directory).lastPathComponent
            items.insert(DownloadItem(id: UUID(), filename: filename, destination: nil,
                                      state: .failed, failureReason: error.localizedDescription), at: 0)
            completionHandler(nil)
        }
    }

    private func observeProgress(of download: WKDownload) {
        let key = ObjectIdentifier(download)
        progressObservations[key] = download.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            let fraction = progress.totalUnitCount > 0 ? progress.fractionCompleted : nil
            let total = progress.totalUnitCount > 0 ? progress.totalUnitCount : nil
            Task { @MainActor in
                guard let self, let id = self.itemIDs[key], let index = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[index].fractionCompleted = fraction
                if let total { self.items[index].byteCount = total }
            }
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        defer {
            downloads.removeValue(forKey: key)
            itemIDs.removeValue(forKey: key)
            temporaryDestinations.removeValue(forKey: key)
            progressObservations.removeValue(forKey: key)
            updateBackgroundTask()
        }
        guard let temporaryURL = temporaryDestinations[key], let id = itemIDs[key],
              let item = items.first(where: { $0.id == id }), let destination = item.destination else { return }
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init)
            update(download) {
                $0.state = .finished
                $0.fractionCompleted = nil
                $0.byteCount = size ?? $0.byteCount
                $0.date = Date()
                $0.canRetry = false
            }
            notice = DownloadNotice(itemID: id, filename: item.filename, state: .finished)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            update(download) {
                $0.state = .failed
                $0.failureReason = error.localizedDescription
                $0.canRetry = $0.sourceURL != nil
            }
            notice = DownloadNotice(itemID: id, filename: item.filename, state: .failed)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let key = ObjectIdentifier(download)
        let temporaryURL = temporaryDestinations.removeValue(forKey: key)
        if let id = itemIDs[key], let resumeData, let temporaryURL {
            // Keep the partial file so the download can continue where it stopped.
            resumable[id] = (resumeData, temporaryURL, WeakWebView(webView: download.webView))
        } else if let temporaryURL {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        update(download) {
            $0.state = .failed
            $0.failureReason = error.localizedDescription
            $0.fractionCompleted = nil
            $0.canRetry = $0.sourceURL != nil || resumeData != nil
        }
        if let id = itemIDs[key], let item = items.first(where: { $0.id == id }) {
            notice = DownloadNotice(itemID: id, filename: item.filename, state: .failed)
        }
        itemIDs.removeValue(forKey: key)
        downloads.removeValue(forKey: key)
        progressObservations.removeValue(forKey: key)
        updateBackgroundTask()
    }

    func cancel(_ item: DownloadItem) {
        guard item.state == .downloading,
              let key = itemIDs.first(where: { $0.value == item.id })?.key,
              let download = downloads[key] else { return }
        // Remove delegate bookkeeping before cancellation can call back.
        itemIDs.removeValue(forKey: key)
        downloads.removeValue(forKey: key)
        progressObservations.removeValue(forKey: key)
        let temporaryURL = temporaryDestinations.removeValue(forKey: key)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].state = .failed
            items[index].failureReason = "Cancelled"
            items[index].fractionCompleted = nil
            items[index].canRetry = items[index].sourceURL != nil
        }
        download.cancel { _ in
            if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
        }
        updateBackgroundTask()
    }

    /// Continues a failed download from its partial data when possible, otherwise starts it again.
    func retry(_ item: DownloadItem, using fallbackWebView: WKWebView?) {
        guard item.state == .failed, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if let saved = resumable.removeValue(forKey: item.id), let webView = saved.webView.webView ?? fallbackWebView {
            items[index].state = .downloading
            items[index].failureReason = nil
            webView.resumeDownload(fromResumeData: saved.data) { [weak self] download in
                guard let self else { return }
                let key = ObjectIdentifier(download)
                self.itemIDs[key] = item.id
                self.temporaryDestinations[key] = saved.temporaryURL
                self.register(download)
                self.observeProgress(of: download)
                self.updateBackgroundTask()
            }
            return
        }
        guard let source = item.sourceURL, let webView = fallbackWebView else { return }
        items.remove(at: index)
        webView.startDownload(using: URLRequest(url: source)) { [weak self] download in
            self?.register(download)
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
        if let saved = resumable.removeValue(forKey: item.id) {
            try? FileManager.default.removeItem(at: saved.temporaryURL)
        }
        items.removeAll { $0.id == item.id }
    }

    /// Asks iOS for extra time so a download can finish if the person leaves the app.
    private func updateBackgroundTask() {
        if activeCount > 0, backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Acute downloads") { [weak self] in
                Task { @MainActor in self?.endBackgroundTask() }
            }
        } else if activeCount == 0 {
            endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
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
