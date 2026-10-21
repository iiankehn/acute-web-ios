import SwiftUI

struct NavigationTabCapsule: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    let height: CGFloat
    @ScaledMetric(relativeTo: .subheadline) private var phoneWidth: CGFloat = 160
    @ScaledMetric(relativeTo: .subheadline) private var padWidth: CGFloat = 196

    private var width: CGFloat {
        min(UIDevice.current.userInterfaceIdiom == .phone ? phoneWidth : padWidth, 320)
    }

    var body: some View {
        HStack(spacing: 0) {
            Button { browser.select(tab) } label: {
                HStack(spacing: 8) {
                    Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                        .foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(tab.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 14)
                .frame(maxWidth: .infinity, minHeight: height)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(tab.title)
            .accessibilityValue(tab.isPrivate ? "Private tab" : "Regular tab")
            .accessibilityIdentifier("toolbarSelect_\(tab.id)")
            Button { browser.close(tab) } label: {
                Image(systemName: "xmark").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(width: 36, height: height).contentShape(Rectangle())
            }
            .accessibilityLabel("Close \(tab.title)")
            .accessibilityIdentifier("toolbarClose_\(tab.id)")
        }
        .frame(width: width, height: height)
        .acuteGlass(cornerRadius: height / 2)
        .help(tab.isPrivate ? "Private Tab" : (tab.url?.absoluteString ?? "New Tab"))
        .contextMenu {
            Button("Duplicate", systemImage: "plus.square.on.square") { browser.duplicate(tab) }
            Button("Close", systemImage: "xmark", role: .destructive) { browser.close(tab) }
        }
    }
}
