import SwiftUI

/// Clearing the query also exits native search so sheet navigation is restored.
struct SearchRecoveryView: View {
    @Binding var query: String
    @Binding var searchPresented: Bool
    let identifier: String

    var body: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No matches for “\(query)”. Try a different search.")
        } actions: {
            Button("Clear Search") {
                query = ""
                searchPresented = false
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(identifier)
        }
    }
}
