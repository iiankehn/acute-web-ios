import Foundation

enum AddressResolver {
    static func resolve(_ rawValue: String, searchEngine: SearchEngine = .duckDuckGo) -> URL? {
        let input = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        let lowercased = input.lowercased()
        if lowercased.hasPrefix("http:") || lowercased.hasPrefix("https:") {
            return WebAddress.url(input, allowMissingScheme: false)
        }
        let unsupported = ["file:", "javascript:", "data:", "blob:", "about:", "intent:", "mailto:", "tel:", "sms:"]
        guard !unsupported.contains(where: { lowercased.hasPrefix($0) }) else { return nil }
        if !input.contains(where: { $0.isWhitespace }),
           (input.contains(".") || lowercased == "localhost" || lowercased.hasPrefix("localhost:") || input.hasPrefix("[")),
           let url = WebAddress.url(input) {
            return url
        }

        var components = URLComponents(string: searchEngine.searchURL)
        components?.queryItems = [URLQueryItem(name: "q", value: input)]
        return components?.url
    }
}
