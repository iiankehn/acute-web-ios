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
                            Text("by CORE").font(.subheadline).foregroundStyle(Color(uiColor: .label))
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section {
                    NavigationLink {
                        SearchEngineSelectionView(preferences: preferences)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Search engine").font(.body)
                            Text(preferences.searchEngine.title).font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(Color(uiColor: .label))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityLabel("Search engine")
                    .accessibilityValue(preferences.searchEngine.title)
                    .accessibilityIdentifier("searchEngineSetting")
                } header: { sectionHeading("Search") }

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
                                        .font(.caption).foregroundStyle(Color(uiColor: .label))
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
                    sectionHeading("Browsing Layout")
                } footer: {
                    details("Phone controls can sit above the page or within thumb reach. Tabs and navigation share one row. Editing, loading and Find show the address field; successful loading can show the page title instead. iPad keeps navigation at the top.")
                        .accessibilityIdentifier("browsingLayoutExplanation")
                }

                Section {
                    Toggle("Block known trackers", isOn: $preferences.blocksTrackers)
                        .onChange(of: preferences.blocksTrackers) { _, _ in applyPrivacyPreferences() }
                    valueRow("Fraudulent website warnings", value: "On")
                    valueRow("Acute telemetry", value: "None")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Acute telemetry")
                        .accessibilityValue("None")
                        .accessibilityIdentifier("telemetryStatus")
                    valueRow("Diagnostic uploads", value: "None")
                    Toggle("Save browsing history", isOn: $preferences.savesHistory)
                    if !history.items.isEmpty {
                        Button(role: .destructive) { deletion = .history } label: {
                            Text("Clear Saved History").foregroundStyle(Color("DestructiveAction"))
                        }
                    }
                } header: {
                    sectionHeading("Privacy Protection")
                } footer: {
                    details("Tracker protection uses WebKit content rules on the device. Browsing activity is not sent to Acute.")
                }

                Section {
                    Label("Private tabs stay out of history and session recovery. Downloaded files remain on this device until you delete them.", systemImage: "hand.raised.fill")
                } header: { sectionHeading("Private Browsing") }

                Section {
                    Button(role: .destructive) {
                        deletion = .websiteData
                    } label: {
                        HStack(spacing: 12) {
                            if isClearingWebsiteData { ProgressView().accessibilityHidden(true) }
                            Text(isClearingWebsiteData ? "Clearing Website Data…" : "Clear Regular Website Data")
                                .foregroundStyle(Color("DestructiveAction"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    .disabled(isClearingWebsiteData)
                    if websiteDataCleared {
                        Label("Regular website data cleared", systemImage: "checkmark.circle.fill")
                    }
                } header: {
                    sectionHeading("Website Data")
                } footer: {
                    details("Removes regular-tab cookies, caches, and website storage. This can sign you out. Bookmarks, history, downloads, and private tabs are not removed. Open pages may store new data.")
                }

                Section {
                    Toggle("Restore regular tabs", isOn: $preferences.restoresTabs)
                        .onChange(of: preferences.restoresTabs) { _, _ in applySessionPreferences() }
                } header: {
                    sectionHeading("Startup")
                } footer: {
                    details("Regular web addresses are saved locally for recovery and may be included in device backups. Private tabs are never saved or restored.")
                        .accessibilityIdentifier("sessionRecoveryExplanation")
                }

                Section {
                    Toggle("Show bookmarks", isOn: $preferences.showsStartBookmarks)
                    Toggle("Show favorites", isOn: $preferences.showsStartFavorites)
                    Toggle("Show recent session sites", isOn: $preferences.showsStartRecentSites)
                } header: { sectionHeading("Start Page") }

                Section {
                    valueRow("Version", value: appVersion)
                    valueRow("Rendering engine", value: "WebKit")
                    NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                        .accessibilityIdentifier("privacyPolicyLink")
                    Link("Support & Feedback", destination: PrivacyPolicy.supportURL)
                } header: { sectionHeading("About") }
            }
            .modifier(SettingsScrollEdge())
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
                    SheetDoneButton { dismiss() }
                }
            }
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(Color(uiColor: .label))
    }

    private func details(_ text: String) -> some View {
        Text(text).font(.body).foregroundStyle(Color(uiColor: .label))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func valueRow(_ title: String, value: String) -> some View {
        LabeledContent {
            Text(value).font(.body).foregroundStyle(Color(uiColor: .label))
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Text(title).font(.body).foregroundStyle(Color(uiColor: .label))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Use the native hard boundary so Settings text does not fade underneath
/// the navigation controls. The toolbar keeps its system Liquid Glass.
private struct SettingsScrollEdge: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            content
        }
#else
        content
#endif
    }
}
