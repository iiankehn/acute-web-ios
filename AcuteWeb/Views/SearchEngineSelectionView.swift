import SwiftUI

struct SearchEngineSelectionView: View {
    @ObservedObject var preferences: BrowserPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(SearchEngine.allCases) { engine in
            Button {
                preferences.searchEngine = engine
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Text(engine.title)
                        .font(.body)
                        .foregroundStyle(Color(uiColor: .label))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if preferences.searchEngine == engine {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.title)
            .accessibilityValue(preferences.searchEngine == engine ? "Selected" : "Not selected")
            .accessibilityAddTraits(preferences.searchEngine == engine ? .isSelected : [])
        }
        .navigationTitle("Search Engine")
        .navigationBarTitleDisplayMode(.inline)
    }
}
