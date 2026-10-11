import Foundation
import WebKit

enum ExternalLinkPolicy {
    static func allows(_ url: URL, navigationType: WKNavigationType, isMainFrame: Bool) -> Bool {
        guard navigationType == .linkActivated, isMainFrame,
              let scheme = url.scheme?.lowercased(), ["mailto", "tel", "sms"].contains(scheme),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        return scheme != "tel" || !components.path.isEmpty || components.host?.isEmpty == false
    }
}
