import Foundation

enum SiteDataScope {
    static func matches(recordName: String, host: String) -> Bool {
        let record = recordName.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let target = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !record.isEmpty, !target.isEmpty else { return false }
        return record == target || target.hasSuffix("." + record) || record.hasSuffix("." + target)
    }
}
