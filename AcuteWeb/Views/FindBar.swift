import SwiftUI

struct FindBar: View {
    @EnvironmentObject private var browser: BrowserStore
    @FocusState private var focused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var resultsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        : AnyLayout(HStackLayout(spacing: 4))
    }

    private var hasQuery: Bool {
        !browser.findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "text.magnifyingglass")
                        .foregroundStyle(.secondary).accessibilityHidden(true)
                }
                TextField("Find on page", text: $browser.findQuery)
                    .accessibilityLabel("Find on page")
                    .accessibilityIdentifier("findField")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit { browser.findInPage() }
                    .onChange(of: browser.findQuery) { _, _ in browser.findInPage() }
                    .layoutPriority(1)
                Button { browser.closeFindBar() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close Find on Page")
                .keyboardShortcut(.escape, modifiers: [])
            }
            resultsLayout {
                Text(browser.findStatus.isEmpty ? "Enter text to find" : browser.findStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("findStatus")
                HStack(spacing: 4) {
                    Spacer(minLength: 8)
                    Button { browser.findInPage(backwards: true) } label: {
                        Image(systemName: "chevron.up").frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Previous Match")
                    .disabled(!hasQuery)
                    Button { browser.findInPage() } label: {
                        Image(systemName: "chevron.down").frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Next Match")
                    .disabled(!hasQuery)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .acuteGlass(cornerRadius: 22)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onAppear { focused = true }
    }
}
