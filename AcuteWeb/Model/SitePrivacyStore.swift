import Foundation

enum MediaCapturePolicy: String, Codable, CaseIterable, Identifiable {
    case ask, allow, block
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ask: return "Ask"
        case .allow: return "Allow"
        case .block: return "Block"
        }
    }
}

struct SitePrivacyPolicy: Codable, Equatable {
    var blocksTrackers = true
    var allowsJavaScript = true
    var mediaCapture = MediaCapturePolicy.ask

    var blocksMediaCapture: Bool { mediaCapture == .block }

    init(blocksTrackers: Bool = true, allowsJavaScript: Bool = true, mediaCapture: MediaCapturePolicy = .ask) {
        self.blocksTrackers = blocksTrackers
        self.allowsJavaScript = allowsJavaScript
        self.mediaCapture = mediaCapture
    }

    private enum CodingKeys: String, CodingKey {
        case blocksTrackers, allowsJavaScript, mediaCapture, blocksMediaCapture
    }

    // Older builds stored only a block flag for camera and microphone.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        blocksTrackers = try values.decodeIfPresent(Bool.self, forKey: .blocksTrackers) ?? true
        allowsJavaScript = try values.decodeIfPresent(Bool.self, forKey: .allowsJavaScript) ?? true
        if let policy = try values.decodeIfPresent(MediaCapturePolicy.self, forKey: .mediaCapture) {
            mediaCapture = policy
        } else {
            mediaCapture = try values.decodeIfPresent(Bool.self, forKey: .blocksMediaCapture) == true ? .block : .ask
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(blocksTrackers, forKey: .blocksTrackers)
        try values.encode(allowsJavaScript, forKey: .allowsJavaScript)
        try values.encode(mediaCapture, forKey: .mediaCapture)
    }
}

@MainActor
final class SitePrivacyStore: ObservableObject {
    @Published private(set) var policies: [String: SitePrivacyPolicy] = [:]
    /// Overrides made from private tabs live only in memory until private browsing ends.
    @Published private(set) var privatePolicies: [String: SitePrivacyPolicy] = [:]
    private let defaultsKey = "sitePrivacyPolicies"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([String: SitePrivacyPolicy].self, from: data) {
            for (host, policy) in saved {
                let key = Self.key(for: host)
                if policies[key] == nil || host == key { policies[key] = policy }
            }
        }
    }

    /// "www." is treated as the same site so one choice covers both common forms of an address.
    static func key(for host: String) -> String {
        let lowered = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return lowered.hasPrefix("www.") && lowered.count > 4 ? String(lowered.dropFirst(4)) : lowered
    }

    func policy(for host: String?, isPrivate: Bool = false) -> SitePrivacyPolicy {
        guard let host, !host.isEmpty else { return SitePrivacyPolicy() }
        let key = Self.key(for: host)
        if isPrivate, let policy = privatePolicies[key] { return policy }
        return policies[key] ?? SitePrivacyPolicy()
    }

    func update(host: String, isPrivate: Bool = false, _ change: (inout SitePrivacyPolicy) -> Void) {
        let key = Self.key(for: host)
        guard !key.isEmpty else { return }
        var policy = policy(for: key, isPrivate: isPrivate)
        change(&policy)
        if isPrivate {
            privatePolicies[key] = policy
            return
        }
        if policy == SitePrivacyPolicy() {
            policies.removeValue(forKey: key)
        } else {
            policies[key] = policy
        }
        persist()
    }

    func reset(host: String, isPrivate: Bool = false) {
        let key = Self.key(for: host)
        if isPrivate {
            privatePolicies.removeValue(forKey: key)
            return
        }
        policies.removeValue(forKey: key)
        persist()
    }

    func resetAll() {
        policies.removeAll()
        persist()
    }

    func endPrivateBrowsing() {
        privatePolicies.removeAll()
    }

    private func persist() {
        guard !policies.isEmpty else {
            defaults.removeObject(forKey: defaultsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(policies) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
