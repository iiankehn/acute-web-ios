import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: BrowserPreferences
    @ObservedObject var history: HistoryStore
    let applyPrivacyPreferences: () -> Void
    let applySessionPreferences: () -> Void
    @Environment(\.dismiss) private var dismiss

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
                        Button("Clear Saved History", role: .destructive) { history.clear() }
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

                Section("About") {
                    LabeledContent("Brand", value: "Acute Web by CORE")
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Rendering engine", value: "WebKit")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
