import SwiftUI

struct SitePrivacyView: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var sitePrivacy: SitePrivacyStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var clearedData = false
    @State private var isClearingData = false
    @State private var confirmsClearing = false

    private var siteHost: String? { browser.selectedTab?.url?.host }
    private var host: String { siteHost ?? "This Website" }
    private var isPrivate: Bool { browser.selectedTab?.isPrivate == true }
    private var policy: SitePrivacyPolicy { sitePrivacy.policy(for: siteHost, isPrivate: isPrivate) }
    private var connectionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    connectionLayout {
                        Image(systemName: browser.selectedTab?.connectionSecurity.symbol ?? "globe")
                            .foregroundStyle(browser.selectedTab?.connectionSecurity == .secure ? Color.accentColor : Color.orange)
                            .frame(width: 40, height: 40)
                            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(host).font(.headline).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(browser.selectedTab?.isPrivate == true ? "Private tab" : "Regular tab")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    LabeledContent("Protocol", value: browser.selectedTab?.url?.scheme?.uppercased() ?? "Unknown")
                    LabeledContent("Security", value: browser.selectedTab?.connectionSecurity.summary ?? "Unknown")
                        .accessibilityIdentifier("siteConnectionSecurity")
                }
                Section {
                    Toggle("Block known trackers", isOn: binding(\.blocksTrackers))
                    Toggle("Allow JavaScript", isOn: binding(\.allowsJavaScript))
                    Picker("Camera and microphone", selection: Binding(
                        get: { policy.mediaCapture },
                        set: { value in
                            guard let siteHost else { return }
                            sitePrivacy.update(host: siteHost, isPrivate: isPrivate) { $0.mediaCapture = value }
                        }
                    )) {
                        ForEach(MediaCapturePolicy.allCases) { option in Text(option.title).tag(option) }
                    }
                } header: {
                    Text("Site Controls")
                } footer: {
                    Text(isPrivate
                         ? "Changes in a private tab are kept only until every private tab is closed. Reload the page to apply JavaScript changes."
                         : "Changes are stored only on this device and also apply to this site’s www address. Reload the page to apply JavaScript changes.")
                    if !browser.preferences.blocksTrackers {
                        Text("Tracker blocking is off in Settings. Turn it on there to use this site's blocking preference.")
                    }
                }
                .disabled(siteHost == nil)

                Section("Website Data") {
                    Button(role: .destructive) {
                        confirmsClearing = true
                    } label: {
                        HStack(spacing: 12) {
                            if isClearingData { ProgressView().accessibilityHidden(true) }
                            Text(isClearingData ? "Clearing Website Data…" : "Clear Cookies and Website Data")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minHeight: 44, alignment: .leading)
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
                        sitePrivacy.reset(host: host, isPrivate: isPrivate)
                        browser.applyPrivacyPreferences()
                    }
                }
                .disabled(siteHost == nil)
            }
            .navigationTitle("Site Privacy")
            .navigationBarTitleDisplayMode(.inline)
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
                guard let siteHost else { return }
                sitePrivacy.update(host: siteHost, isPrivate: isPrivate) { $0[keyPath: keyPath] = value }
                browser.applyPrivacyPreferences()
            }
        )
    }
}
