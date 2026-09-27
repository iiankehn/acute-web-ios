import SwiftUI

struct FindBar: View {
    @EnvironmentObject private var browser: BrowserStore
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.magnifyingglass").foregroundStyle(.secondary)
            TextField("Find on page", text: $browser.findQuery)
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { browser.findInPage() }
            if !browser.findStatus.isEmpty {
                Text(browser.findStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button { browser.findInPage(backwards: true) } label: { Image(systemName: "chevron.up") }
                .disabled(browser.findQuery.isEmpty)
            Button { browser.findInPage() } label: { Image(systemName: "chevron.down") }
                .disabled(browser.findQuery.isEmpty)
            Button { browser.closeFindBar() } label: { Image(systemName: "xmark") }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(.regularMaterial)
        .onAppear { focused = true }
    }
}
