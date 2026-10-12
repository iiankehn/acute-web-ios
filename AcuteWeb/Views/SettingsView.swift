import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: BrowserPreferences
    @ObservedObject var history: HistoryStore
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
        case history, websiteData
        var title: String { self == .history ? "Clear Saved History?" : "Clear Regular Website Data?" }
    }
    @State private var deletion: Deletion?
    @State private var isClearingWebsiteData = false
    @State private var websiteDataCleared = false

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
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
                    Text("Phone controls can sit above the page or within thumb reach. iPad keeps persistent navigation. Editing, loading and Find keep controls expanded.")
                }

                Section {
                    Toggle("Block known trackers", isOn: $preferences.blocksTrackers)
                        .onChange(of: preferences.blocksTrackers) { _, _ in applyPrivacyPreferences() }
                    LabeledContent("Fraudulent website warnings", value: "On")
                    LabeledContent("Acute telemetry", value: "None")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Acute telemetry")
                        .accessibilityValue("None")
                        .accessibilityIdentifier("telemetryStatus")
                    LabeledContent("Diagnostic uploads", value: "None")
                    Toggle("Save browsing history", isOn: $preferences.savesHistory)
                    if !history.items.isEmpty {
                        Button("Clear Saved History", role: .destructive) { deletion = .history }
                    }
                } header: {
                    Text("Privacy Protection")
                } footer: {
                    Text("Tracker protection uses WebKit content rules on the device. Browsing activity is not sent to Acute.")
                }

                Section("Private Browsing") {
                    Label("Private tabs stay out of history and session recovery. Downloaded files remain on this device until you delete them.", systemImage: "hand.raised.fill")
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
                    Text("Regular web addresses are stored only on this device for recovery. Private tabs are never saved or restored.")
                        .accessibilityIdentifier("sessionRecoveryExplanation")
                }

                Section("Start Page") {
                    Toggle("Show bookmarks", isOn: $preferences.showsStartBookmarks)
                    Toggle("Show favorites", isOn: $preferences.showsStartFavorites)
                    Toggle("Show recent session sites", isOn: $preferences.showsStartRecentSites)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Rendering engine", value: "WebKit")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert(deletion?.title ?? "Confirm Deletion", isPresented: Binding(
                get: { deletion != nil }, set: { if !$0 { deletion = nil } }
            ), presenting: deletion) { target in
                if target == .history {
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
                Button("Cancel", role: .cancel) {}
            } message: { target in
                Text(target == .history ? "This removes all saved visits from this device." : "This can sign you out of websites in regular tabs. Your bookmarks, history, downloads, and private tabs stay unchanged.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
