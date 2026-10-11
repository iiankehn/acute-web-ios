import SwiftUI

struct DesktopTabStrip: View {
    @EnvironmentObject private var browser: BrowserStore

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(browser.tabs) { tab in
                        DesktopTab(tab: tab)
                    }
                }
                .padding(4)
            }
            .scrollIndicators(.hidden)
            Button { browser.newTab() } label: {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }
            .accessibilityLabel("New Tab")
            .help("New Tab (Command-T)")
        }
        .acuteGlass(cornerRadius: 18)
        .accessibilityIdentifier("desktopTabStrip")
    }
}

private struct DesktopTab: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab

    private var selected: Bool { browser.selectedTabID == tab.id }

    var body: some View {
        HStack(spacing: 0) {
            Button { browser.select(tab) } label: {
                HStack(spacing: 8) {
                    Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                        .foregroundStyle(selected ? Color.accentColor : .secondary)
                    Text(tab.title).font(.subheadline.weight(selected ? .semibold : .regular)).lineLimit(1)
                }
                .frame(width: 148, height: 44, alignment: .leading)
                .padding(.leading, 12)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(tab.title)
            .accessibilityValue(selected ? "Selected tab" : (tab.isPrivate ? "Private tab" : "Regular tab"))
            .help(tab.isPrivate ? "Private Tab" : (tab.url?.absoluteString ?? "New Tab"))
            Button { browser.close(tab) } label: {
                Image(systemName: "xmark").font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close \(tab.title)")
        }
        .background(selected ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .bottom) {
            if selected {
                Capsule().fill(Color.accentColor).frame(width: 28, height: 3).padding(.bottom, 3)
                    .accessibilityHidden(true)
            }
        }
        .contextMenu {
            Button("Duplicate", systemImage: "plus.square.on.square") { browser.duplicate(tab) }
            Button("Close", systemImage: "xmark", role: .destructive) { browser.close(tab) }
        }
    }
}
