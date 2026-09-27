import Foundation

struct SitePrivacyPolicy: Codable, Equatable {
    var blocksTrackers = true
    var allowsJavaScript = true
    var blocksMediaCapture = false
}

@MainActor
final class SitePrivacyStore: ObservableObject {
    @Published private(set) var policies: [String: SitePrivacyPolicy] = [:]
    private let defaultsKey = "sitePrivacyPolicies"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey) {
            policies = (try? JSONDecoder().decode([String: SitePrivacyPolicy].self, from: data)) ?? [:]
        }
    }

    func policy(for host: String?) -> SitePrivacyPolicy {
        guard let host else { return SitePrivacyPolicy() }
        return policies[host.lowercased()] ?? SitePrivacyPolicy()
    }

    func update(host: String, _ change: (inout SitePrivacyPolicy) -> Void) {
        let key = host.lowercased()
        var policy = policy(for: key)
        change(&policy)
        if policy == SitePrivacyPolicy() {
            policies.removeValue(forKey: key)
        } else {
            policies[key] = policy
        }
        persist()
    }

    func reset(host: String) {
        policies.removeValue(forKey: host.lowercased())
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(policies) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
