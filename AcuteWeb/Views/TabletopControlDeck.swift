import SwiftUI

/// Controls below a horizontal fold when iPhone Duo is half open and resting on a surface:
/// the address row, large navigation buttons and a strip of open tabs. The page fills the upper half.
struct TabletopControlDeck: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @ObservedObject var preferences: BrowserPreferences
    let showsOtherTabs: Bool
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 64

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BrowserToolbar(tab: tab, preferences: preferences, mode: .wideRow,
                               showsOtherTabs: false, hidesNavigationControls: true)
                if browser.showsFindBar { FindBar() }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    deckButton("Back", symbol: "chevron.backward") { tab.webView.goBack() }
                        .disabled(!tab.canGoBack)
                    deckButton("Forward", symbol: "chevron.forward") { tab.webView.goForward() }
                        .disabled(!tab.canGoForward)
                    deckButton("Find", symbol: "text.magnifyingglass") { browser.showsFindBar = true }
                        .disabled(tab.url == nil)
                    if let url = tab.url {
                        ShareLink(item: url) { deckLabel("Share", symbol: "square.and.arrow.up") }
                    }
                    deckButton("Tabs", symbol: "square.on.square") {
                        tab.captureSnapshot()
                        browser.showsTabs = true
                    }
                }
                .padding(.horizontal, 12)
                if showsOtherTabs {
                    HStack {
                        Text("Tabs").font(.headline).accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("New Tab", systemImage: "plus") { browser.newTab() }
                            .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(browser.tabs) { candidate in
                                DeckTabChip(tab: candidate, isSelected: candidate.id == tab.id)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .accessibilityIdentifier("tabletopControlDeck")
    }

    private func deckButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { deckLabel(title, symbol: symbol) }
            .buttonStyle(.plain)
    }

    private func deckLabel(_ title: String, symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.title3.weight(.medium))
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity, minHeight: buttonHeight)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct DeckTabChip: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    let isSelected: Bool

    var body: some View {
        Button { browser.select(tab) } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe").foregroundStyle(.secondary)
                Text(tab.title).lineLimit(1)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .frame(maxWidth: 220, minHeight: 44)
            .background(Color(uiColor: .systemBackground), in: Capsule())
            .overlay { Capsule().stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? "Selected tab" : (tab.isPrivate ? "Private tab" : "Regular tab"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
