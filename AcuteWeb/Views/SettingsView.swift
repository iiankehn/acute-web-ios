import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: BrowserPreferences
    let applyPrivacyPreferences: () -> Void
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

                Section("Privacy Protection") {
                    Toggle("Block known trackers", isOn: $preferences.blocksTrackers)
                        .onChange(of: preferences.blocksTrackers) { _, _ in applyPrivacyPreferences() }
                    LabeledContent("Fraudulent website warnings", value: "On")
                    LabeledContent("Acute telemetry", value: "None")
                    LabeledContent("Diagnostic uploads", value: "None")
                } footer: {
                    Text("Tracker protection uses WebKit content rules on the device. Browsing activity is not sent to Acute.")
                }

                Section("Private Browsing") {
                    Label("Private tabs use a non-persistent website data store and are excluded from session history.", systemImage: "hand.raised.fill")
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0 Preview")
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
