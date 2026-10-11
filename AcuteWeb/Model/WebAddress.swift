import Foundation

enum WebAddress {
    static func url(_ rawValue: String, allowMissingScheme: Bool = true) -> URL? {
        let input = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !input.contains(where: { $0.isWhitespace }) else { return nil }
        let parsed = URLComponents(string: input)
        let scheme = parsed?.scheme?.lowercased()
        let candidate: String
        if scheme == "http" || scheme == "https" {
            candidate = input
        } else {
            guard allowMissingScheme, !input.contains("://") else { return nil }
            // A host followed by a port can be parsed as a URI scheme. Other schemes stay unsupported.
            if let scheme, scheme != "localhost", !scheme.contains(".") { return nil }
            candidate = "https://" + input
        }
        guard let parts = URLComponents(string: candidate),
              let host = parts.host, !host.isEmpty, host != ".",
              let url = parts.url else { return nil }
        if let port = parts.port, !(1...65535).contains(port) { return nil }
        return url
    }
}
