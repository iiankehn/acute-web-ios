import Foundation

enum AddressResolver {
    static func resolve(_ rawValue: String) -> URL? {
        let input = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        if let explicit = URL(string: input), let scheme = explicit.scheme,
           ["http", "https"].contains(scheme.lowercased()) {
            return explicit
        }

        if !input.contains(where: { $0.isWhitespace }),
           (input.contains(".") || input == "localhost"),
           let url = URL(string: "https://\(input)") {
            return url
        }

        var components = URLComponents(string: "https://duckduckgo.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: input)]
        return components?.url
    }
}

