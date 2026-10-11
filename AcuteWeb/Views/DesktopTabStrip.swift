import SwiftUI

struct DesktopTabStrip: View {
    @EnvironmentObject private var browser: BrowserStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(browser.tabs) { tab in
                            DesktopTab(tab: tab).id(tab.id)
                        }
                    }
                    .padding(4)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    if let id = browser.selectedTabID { proxy.scrollTo(id, anchor: .center) }
                }
                .onChange(of: browser.selectedTabID) { _, id in
                    guard let id else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var selected: Bool { browser.selectedTabID == tab.id }

    var body: some View {
        HStack(spacing: 0) {
            Button { browser.select(tab) } label: {
                HStack(spacing: 8) {
                    Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                        .foregroundStyle(selected ? Color.accentColor : .secondary)
                    Text(tab.title).font(.subheadline.weight(selected ? .semibold : .regular))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 220 : 148, alignment: .leading)
                .frame(minHeight: 44)
                .padding(.leading, 12)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(tab.title)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityValue(selected ? "Selected tab" : (tab.isPrivate ? "Private tab" : "Regular tab"))
            .accessibilityIdentifier("desktopSelect_\(tab.id)")
            .hoverEffect(.highlight)
            .help(tab.isPrivate ? "Private Tab" : (tab.url?.absoluteString ?? "New Tab"))
            Button { browser.close(tab) } label: {
                Image(systemName: "xmark").font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close \(tab.title)")
            .hoverEffect(.highlight)
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
