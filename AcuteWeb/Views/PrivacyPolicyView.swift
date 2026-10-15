import SwiftUI

enum PrivacyPolicy {
    static let publicURL = URL(string: "https://github.com/iiankehn/acute-web-ios/blob/main/PRIVACY.md")!
    static let supportURL = URL(string: "https://github.com/iiankehn/acute-web-ios/issues")!

    static var text: String? {
        guard let url = Bundle.main.url(forResource: "PRIVACY", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let text = PrivacyPolicy.text {
                    Text(.init(text))
                        .font(.body)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("privacyPolicyText")
                } else {
                    ContentUnavailableView("Privacy Policy Unavailable", systemImage: "doc.text",
                                           description: Text("Use the online policy below."))
                }
                Link("View Current Policy Online", destination: PrivacyPolicy.publicURL)
                    .frame(minHeight: 44, alignment: .leading)
                Link("Contact via GitHub Issues", destination: PrivacyPolicy.supportURL)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
