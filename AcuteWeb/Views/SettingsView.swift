import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: BrowserPreferences
    @ObservedObject var history: HistoryStore
    @ObservedObject var sitePrivacy: SitePrivacyStore
    @ObservedObject var favorites: FavoritesStore
    @EnvironmentObject private var browser: BrowserStore
    let clearRegularWebsiteData: (@escaping () -> Void) -> Void
    let applyPrivacyPreferences: () -> Void
    let applySessionPreferences: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var brandLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        : AnyLayout(HStackLayout(spacing: 14))
    }
    private var layoutOptions: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        : AnyLayout(HStackLayout(spacing: 12))
    }
    private enum Deletion {
        case history, historyAfterDisabling, websiteData
        var title: String {
            switch self {
            case .history: return "Clear Saved History?"
            case .historyAfterDisabling: return "Also Clear Saved History?"
            case .websiteData: return "Clear Regular Website Data?"
            }
        }
    }
    @State private var deletion: Deletion?
    @State private var isClearingWebsiteData = false
    @State private var websiteDataCleared = false

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.5.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    brandLayout {
                        Image("AcuteMark").resizable().scaledToFit()
                            .frame(width: 48, height: 48).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Acute Web").font(.title3.weight(.semibold))
                            Text("by CORE").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section("Search") {
                    Picker("Search engine", selection: $preferences.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in
                            Text(engine.title).tag(engine)
                        }
                    }
                }

                Section {
                    layoutOptions {
                        ForEach(PhoneControlsPosition.allCases) { position in
                            Button { preferences.phoneControlsPosition = position } label: {
                                VStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(.secondary, lineWidth: 1.5)
                                        .frame(width: 24, height: 40)
                                        .overlay(alignment: position == .top ? .top : .bottom) {
                                            Capsule().fill(Color.accentColor).frame(width: 16, height: 4).padding(4)
                                        }
                                        .accessibilityHidden(true)
                                    HStack(spacing: 6) {
                                        Text(position.title).font(.subheadline.weight(.semibold))
                                        if preferences.phoneControlsPosition == position {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.accentColor)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    Text(position == .top ? "Above the page" : "Within thumb reach")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 96)
                                .padding(8)
                                .background(preferences.phoneControlsPosition == position ? Color.accentColor.opacity(0.1) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 16))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(preferences.phoneControlsPosition == position ? Color.accentColor : Color.secondary.opacity(0.2),
                                                lineWidth: preferences.phoneControlsPosition == position ? 2 : 1)
                                        .allowsHitTesting(false)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(position.title) Controls")
                            .accessibilityValue(preferences.phoneControlsPosition == position ? "Selected" : "Not selected")
                            .accessibilityAddTraits(preferences.phoneControlsPosition == position ? .isSelected : [])
                            .accessibilityIdentifier("phoneLayout_\(position.rawValue)")
                        }
                    }
                    Toggle("Condense controls after loading", isOn: $preferences.condensesPhoneControls)
                    Toggle("Show page title in compact bar", isOn: $preferences.showsCompactPageTitle)
                        .disabled(!preferences.condensesPhoneControls)
                } header: {
                    Text("Browsing Layout")
                } footer: {
                    Text("Phone controls can sit above the page or within thumb reach. Tabs and navigation share one row. Editing, loading and Find show the address field; successful loading can show the page title instead. Wide windows keep navigation at the top, and iPhone Duo moves navigation buttons to the side where iOS places its controls.")
                }

                Section {
                    Toggle("Show tabs in sidebar", isOn: $preferences.showsTabsInSidebar)
                        .accessibilityIdentifier("showsTabsInSidebar")
                } header: {
                    Text("Tabs")
                } footer: {
                    Text("Tabs normally stay in the navigation bar, and the sidebar in wide windows on iPad and iPhone Duo shows Bookmarks, History and Downloads. Turn this on to list tabs at the top of the sidebar instead.")
                }

                Section {
                    Toggle("Block known trackers", isOn: $preferences.blocksTrackers)
                        .onChange(of: preferences.blocksTrackers) { _, _ in applyPrivacyPreferences() }
                    if preferences.blocksTrackers && browser.trackerProtectionUnavailable {
                        Label("Tracker rules couldn’t be loaded, so trackers aren’t being blocked right now. Acute Web will try again on the next page load.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("trackerProtectionUnavailable")
                    }
                    LabeledContent("Fraudulent website warnings", value: "On")
                    LabeledContent("Acute telemetry", value: "None")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Acute telemetry")
                        .accessibilityValue("None")
                        .accessibilityIdentifier("telemetryStatus")
                    LabeledContent("Diagnostic uploads", value: "None")
                    Toggle("Save browsing history", isOn: $preferences.savesHistory)
                        .onChange(of: preferences.savesHistory) { _, saves in
                            if !saves && !history.items.isEmpty { deletion = .historyAfterDisabling }
                        }
                    NavigationLink {
                        SitePrivacyListView(sitePrivacy: sitePrivacy)
                    } label: {
                        LabeledContent("Site Settings", value: sitePrivacy.policies.isEmpty ? "None" : "\(sitePrivacy.policies.count)")
                    }
                    .accessibilityIdentifier("siteSettingsLink")
                    if !history.items.isEmpty {
                        Button("Clear Saved History", role: .destructive) { deletion = .history }
                    }
                } header: {
                    Text("Privacy Protection")
                } footer: {
                    Text("Tracker protection uses WebKit content rules on the device. Browsing activity is not sent to Acute.")
                }

                Section("Private Browsing") {
                    Label("Private tabs stay out of history and session recovery. They share sign-ins with each other until every private tab is closed. Site settings changed in a private tab are forgotten then too. Downloaded files remain on this device, and visible in Files, until you delete them.", systemImage: "hand.raised.fill")
                }

                Section {
                    Button(role: .destructive) {
                        deletion = .websiteData
                    } label: {
                        HStack(spacing: 12) {
                            if isClearingWebsiteData { ProgressView().accessibilityHidden(true) }
                            Text(isClearingWebsiteData ? "Clearing Website Data…" : "Clear Regular Website Data")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    .disabled(isClearingWebsiteData)
                    if websiteDataCleared {
                        Label("Regular website data cleared", systemImage: "checkmark.circle.fill")
                    }
                } header: {
                    Text("Website Data")
                } footer: {
                    Text("Removes regular-tab cookies, caches, and website storage. This can sign you out. Bookmarks, history, downloads, and private tabs are not removed. Open pages may store new data.")
                }

                Section {
                    Toggle("Restore regular tabs", isOn: $preferences.restoresTabs)
                        .onChange(of: preferences.restoresTabs) { _, _ in applySessionPreferences() }
                } header: {
                    Text("Startup")
                } footer: {
                    Text("Regular web addresses are saved locally for recovery and may be included in device backups. Private tabs are never saved or restored.")
                        .accessibilityIdentifier("sessionRecoveryExplanation")
                }

                Section {
                    Toggle("Show bookmarks", isOn: $preferences.showsStartBookmarks)
                    Toggle("Show favorites", isOn: $preferences.showsStartFavorites)
                    Toggle("Show recent session sites", isOn: $preferences.showsStartRecentSites)
                    Button("Restore Default Favorites") { favorites.restoreDefaults() }
                } header: {
                    Text("Start Page")
                } footer: {
                    Text("Add the current page to Favorites from More, then Saved Content. Touch and hold a favorite to remove it.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Rendering engine", value: "WebKit")
                    NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                        .accessibilityIdentifier("privacyPolicyLink")
                    Link("Support & Feedback", destination: PrivacyPolicy.supportURL)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert(deletion?.title ?? "Confirm Deletion", isPresented: Binding(
                get: { deletion != nil }, set: { if !$0 { deletion = nil } }
            ), presenting: deletion) { target in
                if target != .websiteData {
                    Button("Clear Saved History", role: .destructive) { history.clear() }
                } else {
                    Button("Clear Website Data", role: .destructive) {
                        isClearingWebsiteData = true
                        websiteDataCleared = false
                        clearRegularWebsiteData {
                            isClearingWebsiteData = false
                            websiteDataCleared = true
                        }
                    }
                }
                Button(target == .historyAfterDisabling ? "Keep History" : "Cancel", role: .cancel) {}
            } message: { target in
                switch target {
                case .history: Text("This removes all saved visits from this device.")
                case .historyAfterDisabling: Text("New visits won’t be saved. History saved earlier stays on this device unless you clear it.")
                case .websiteData: Text("This can sign you out of websites in regular tabs. Your bookmarks, history, downloads, and private tabs stay unchanged.")
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SitePrivacyListView: View {
    @ObservedObject var sitePrivacy: SitePrivacyStore
    @State private var confirmsReset = false

    private var hosts: [String] {
        sitePrivacy.policies.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        Group {
            if hosts.isEmpty {
                ContentUnavailableView("No Site Settings", systemImage: "shield.lefthalf.filled",
                                       description: Text("Choices you make in Site Privacy for regular tabs appear here."))
            } else {
                List {
                    Section {
                        ForEach(hosts, id: \.self) { host in
                            let policy = sitePrivacy.policy(for: host)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(host).font(.body.weight(.medium))
                                Text(summary(policy)).font(.caption).foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .swipeActions {
                                Button("Reset", role: .destructive) { sitePrivacy.reset(host: host) }
                            }
                            .contextMenu {
                                Button("Reset Site Settings", systemImage: "arrow.counterclockwise", role: .destructive) {
                                    sitePrivacy.reset(host: host)
                                }
                            }
                        }
                    } footer: {
                        Text("A setting for a site also applies to its www address. Settings from private tabs are never saved.")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Site Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !hosts.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset All", role: .destructive) { confirmsReset = true }
                }
            }
        }
        .confirmationDialog("Reset All Site Settings?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Reset All", role: .destructive) { sitePrivacy.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every site returns to the default tracker, JavaScript and camera and microphone settings.")
        }
    }

    private func summary(_ policy: SitePrivacyPolicy) -> String {
        var parts: [String] = []
        if !policy.blocksTrackers { parts.append("Trackers allowed") }
        if !policy.allowsJavaScript { parts.append("JavaScript off") }
        switch policy.mediaCapture {
        case .allow: parts.append("Camera and microphone allowed")
        case .block: parts.append("Camera and microphone blocked")
        case .ask: break
        }
        return parts.isEmpty ? "Default settings" : parts.joined(separator: " · ")
    }
}
