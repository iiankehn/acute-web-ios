import SwiftUI

struct SitePrivacyView: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var sitePrivacy: SitePrivacyStore
    @Environment(\.dismiss) private var dismiss
    @State private var clearedData = false

    private var host: String { browser.selectedTab?.url?.host ?? "This Website" }
    private var policy: SitePrivacyPolicy { sitePrivacy.policy(for: host) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Block known trackers", isOn: binding(\.blocksTrackers))
                    Toggle("Allow JavaScript", isOn: binding(\.allowsJavaScript))
                    Toggle("Always block camera and microphone", isOn: binding(\.blocksMediaCapture))
                } header: {
                    Text(host)
                } footer: {
                    Text("Changes are stored only on this device. Reload the page to apply JavaScript changes.")
                }

                Section("Website Data") {
                    Button("Clear Cookies and Website Data", role: .destructive) {
                        browser.clearSiteData(host: host) { clearedData = true }
                    }
                    if clearedData { Label("Website data cleared", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }

                Section {
                    Button("Reset Site Settings") {
                        sitePrivacy.reset(host: host)
                        browser.applyPrivacyPreferences()
                    }
                }
            }
            .navigationTitle("Site Privacy")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<SitePrivacyPolicy, Bool>) -> Binding<Bool> {
        Binding(
            get: { policy[keyPath: keyPath] },
            set: { value in
                sitePrivacy.update(host: host) { $0[keyPath: keyPath] = value }
                browser.applyPrivacyPreferences()
            }
        )
    }
}
