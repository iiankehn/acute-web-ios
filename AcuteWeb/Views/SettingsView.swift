import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: BrowserPreferences
    @ObservedObject var history: HistoryStore
    let applyPrivacyPreferences: () -> Void
    let applySessionPreferences: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsHistoryDeletion = false

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    Picker("Search engine", selection: $preferences.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in
                            Text(engine.title).tag(engine)
                        }
                    }
                }

                Section {
                    Toggle("Block known trackers", isOn: $preferences.blocksTrackers)
                        .onChange(of: preferences.blocksTrackers) { _, _ in applyPrivacyPreferences() }
                    LabeledContent("Fraudulent website warnings", value: "On")
                    LabeledContent("Acute telemetry", value: "None")
                    LabeledContent("Diagnostic uploads", value: "None")
                    Toggle("Save browsing history", isOn: $preferences.savesHistory)
                    if !history.items.isEmpty {
                        Button("Clear Saved History", role: .destructive) { confirmsHistoryDeletion = true }
                    }
                } header: {
                    Text("Privacy Protection")
                } footer: {
                    Text("Tracker protection uses WebKit content rules on the device. Browsing activity is not sent to Acute.")
                }

                Section("Private Browsing") {
                    Label("Private tabs use a non-persistent website data store and are excluded from recent sites and saved history.", systemImage: "hand.raised.fill")
                }

                Section {
                    Toggle("Restore regular tabs", isOn: $preferences.restoresTabs)
                        .onChange(of: preferences.restoresTabs) { _, _ in applySessionPreferences() }
                } header: {
                    Text("Startup")
                } footer: {
                    Text("Regular web addresses are stored only on this device for recovery. Private tabs are never saved or restored.")
                }

                Section("Start Page") {
                    Toggle("Show bookmarks", isOn: $preferences.showsStartBookmarks)
                    Toggle("Show favorites", isOn: $preferences.showsStartFavorites)
                    Toggle("Show recent session sites", isOn: $preferences.showsStartRecentSites)
                }

                Section("About") {
                    LabeledContent("Brand", value: "Acute Web by CORE")
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Rendering engine", value: "WebKit")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Clear saved browsing history?", isPresented: $confirmsHistoryDeletion, titleVisibility: .visible) {
                Button("Clear Saved History", role: .destructive) { history.clear() }
            } message: {
                Text("This removes all saved visits from this device.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
