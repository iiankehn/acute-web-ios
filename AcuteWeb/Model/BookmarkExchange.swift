import Foundation

/// Reads and writes the Netscape bookmark file format used by Safari, Firefox and Chrome.
enum BookmarkExchange {
    static func exportHTML(_ sites: [SavedSite]) -> String {
        var lines = [
            "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
            "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">",
            "<TITLE>Bookmarks</TITLE>",
            "<H1>Bookmarks</H1>",
            "<DL><p>"
        ]
        func entry(_ site: SavedSite, indent: String) -> String {
            let added = Int(site.savedAt.timeIntervalSince1970)
            return "\(indent)<DT><A HREF=\"\(escape(site.address))\" ADD_DATE=\"\(added)\">\(escape(site.title))</A>"
        }
        for site in sites where site.folder == nil {
            lines.append(entry(site, indent: "    "))
        }
        let folders = Array(Set(sites.compactMap(\.folder))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        for folder in folders {
            lines.append("    <DT><H3>\(escape(folder))</H3>")
            lines.append("    <DL><p>")
            for site in sites where site.folder == folder {
                lines.append(entry(site, indent: "        "))
            }
            lines.append("    </DL><p>")
        }
        lines.append("</DL><p>")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Returns HTTP and HTTPS bookmarks. Only the innermost folder name is kept.
    static func importHTML(_ html: String) -> [SavedSite] {
        var sites: [SavedSite] = []
        var folders: [String?] = []
        var pendingFolder: String?
        let scanner = Scanner(string: html)
        scanner.charactersToBeSkipped = nil
        while !scanner.isAtEnd {
            _ = scanner.scanUpToString("<")
            guard scanner.scanString("<") != nil, let tag = scanner.scanUpToString(">") else { break }
            _ = scanner.scanString(">")
            let name = tag.split(separator: " ", maxSplits: 1).first.map { $0.uppercased() } ?? ""
            switch name {
            case "H3":
                pendingFolder = unescape(scanner.scanUpToString("<") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            case "DL":
                folders.append(pendingFolder)
                pendingFolder = nil
            case "/DL":
                if !folders.isEmpty { folders.removeLast() }
            case "A":
                let title = unescape(scanner.scanUpToString("<") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard let href = attribute("HREF", in: tag), let url = WebAddress.url(unescape(href), allowMissingScheme: false) else { continue }
                let date = attribute("ADD_DATE", in: tag).flatMap { TimeInterval($0) }
                    .map { Date(timeIntervalSince1970: $0) } ?? Date()
                let folder: String? = folders.compactMap { $0 }.last { !$0.isEmpty }
                sites.append(SavedSite(id: UUID(), title: title.isEmpty ? (url.host ?? url.absoluteString) : title,
                                       address: url.absoluteString, savedAt: date, folder: folder))
            default:
                continue
            }
        }
        return sites
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        guard let range = tag.range(of: name + "=\"", options: .caseInsensitive) else { return nil }
        let rest = tag[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func unescape(_ value: String) -> String {
        value.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
