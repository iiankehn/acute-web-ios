import SwiftUI

struct SitePrivacyView: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var sitePrivacy: SitePrivacyStore
    @Environment(\.dismiss) private var dismiss
    @State private var clearedData = false
    @State private var isClearingData = false
    @State private var confirmsClearing = false

    private var host: String { browser.selectedTab?.url?.host ?? "This Website" }
    private var policy: SitePrivacyPolicy { sitePrivacy.policy(for: host) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    LabeledContent("Address", value: host)
                    LabeledContent("Protocol", value: browser.selectedTab?.url?.scheme?.uppercased() ?? "Unknown")
                }
                Section {
                    Toggle("Block known trackers", isOn: binding(\.blocksTrackers))
                    Toggle("Allow JavaScript", isOn: binding(\.allowsJavaScript))
                    Toggle("Always block camera and microphone", isOn: binding(\.blocksMediaCapture))
                } header: {
                    Text(host)
                } footer: {
                    Text("Changes are stored only on this device. Reload the page to apply JavaScript changes.")
                    if !browser.preferences.blocksTrackers {
                        Text("Tracker blocking is off in Settings. Turn it on there to use this site's blocking preference.")
                    }
                }

                Section("Website Data") {
                    Button(isClearingData ? "Clearing Website Data…" : "Clear Cookies and Website Data", role: .destructive) {
                        confirmsClearing = true
                    }
                    .disabled(isClearingData)
                    if clearedData { Label("Website data cleared", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }

                Section {
                    Button("Reload with These Settings", systemImage: "arrow.clockwise") {
                        browser.selectedTab?.webView.reload()
                        dismiss()
                    }
                    Button("Reset Site Settings") {
                        sitePrivacy.reset(host: host)
                        browser.applyPrivacyPreferences()
                    }
                }
            }
            .navigationTitle("Site Privacy")
            .confirmationDialog("Clear Website Data?", isPresented: $confirmsClearing, titleVisibility: .visible) {
                Button("Clear Website Data", role: .destructive) {
                    isClearingData = true
                    clearedData = false
                    browser.clearSiteData(host: host) {
                        isClearingData = false
                        clearedData = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can sign you out. WebKit may share cookies and data with this domain's subdomains.")
            }
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
