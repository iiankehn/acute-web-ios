import XCTest
@testable import AcuteWeb

final class DownloadCenterTests: XCTestCase {
    @MainActor
    func testRestartRecoversFinishedFilesAndExcludesPartialDownloads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let older = directory.appendingPathComponent("older.txt")
        let newer = directory.appendingPathComponent("newer.pdf")
        try Data("old".utf8).write(to: older)
        try Data("new".utf8).write(to: newer)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: newer.path)
        let partial = directory.appendingPathComponent(".in-progress", isDirectory: true)
        try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        try Data("incomplete".utf8).write(to: partial.appendingPathComponent("unfinished"))
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("folder"), withIntermediateDirectories: true)

        let center = DownloadCenter(directory: directory)
        XCTAssertEqual(center.items.map(\.filename), ["newer.pdf", "older.txt"])
        XCTAssertTrue(center.items.allSatisfy { $0.state == .finished })
        XCTAssertEqual(center.items.first?.destination, newer)
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
        XCTAssertEqual(try Data(contentsOf: newer), Data("new".utf8))
    }

    @MainActor
    func testDuplicateNamesPreserveExistingDownloads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("existing".utf8).write(to: directory.appendingPathComponent("report.pdf"))
        try Data("also existing".utf8).write(to: directory.appendingPathComponent("report 2.pdf"))
        let center = DownloadCenter(directory: directory)
        XCTAssertEqual(center.uniqueDestination(for: "report.pdf", in: directory).lastPathComponent, "report 3.pdf")
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("report.pdf")), Data("existing".utf8))
    }

    @MainActor
    func testUnsafeAndEmptyNamesStayInsideDownloadsDirectory() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let center = DownloadCenter(directory: directory)
        for name in ["", " ", ".", "..", "../secret", "path/to/file.txt", "path\\file.txt", ".hidden"] {
            let destination = center.uniqueDestination(for: name, in: directory)
            XCTAssertEqual(destination.deletingLastPathComponent().path, directory.path)
            XCTAssertFalse(destination.lastPathComponent.hasPrefix("."))
        }
    }
}
