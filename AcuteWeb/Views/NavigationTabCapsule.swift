import SwiftUI

struct NavigationTabCapsule: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    let height: CGFloat

    var body: some View {
        Button { browser.select(tab) } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                    .foregroundStyle(.secondary).accessibilityHidden(true)
                Text(tab.title).font(.subheadline.weight(.medium)).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(width: UIDevice.current.userInterfaceIdiom == .phone ? 144 : 180, height: height)
            .contentShape(Rectangle())
        }
        .acuteGlass(cornerRadius: height / 2)
        .accessibilityLabel(tab.title)
        .accessibilityValue(tab.isPrivate ? "Private tab" : "Regular tab")
        .accessibilityIdentifier("toolbarSelect_\(tab.id)")
        .help(tab.isPrivate ? "Private Tab" : (tab.url?.absoluteString ?? "New Tab"))
        .contextMenu {
            Button("Duplicate", systemImage: "plus.square.on.square") { browser.duplicate(tab) }
            Button("Close", systemImage: "xmark", role: .destructive) { browser.close(tab) }
        }
    }
}
