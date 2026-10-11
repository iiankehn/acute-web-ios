import SwiftUI

struct TabSidebar: View {
    @EnvironmentObject private var browser: BrowserStore

    var body: some View {
        List {
            ForEach(browser.tabs) { tab in
                SidebarTabRow(tab: tab)
                    .listRowBackground(browser.selectedTabID == tab.id ? Color.accentColor.opacity(0.12) : Color.clear)
                    .swipeActions {
                        Button(role: .destructive) { browser.close(tab) } label: {
                            Label("Close", systemImage: "xmark")
                        }
                    }
                    .contextMenu {
                        Button("Duplicate", systemImage: "plus.square.on.square") { browser.duplicate(tab) }
                        Button("Close", systemImage: "xmark", role: .destructive) { browser.close(tab) }
                    }
            }
            .onMove(perform: browser.moveTabs)
        }
        .navigationTitle("Acute Web")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Tab", systemImage: "plus") { browser.newTab() }
                    Button("New Private Tab", systemImage: "hand.raised.fill") { browser.newTab(isPrivate: true) }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("New Tab Options")
            }
        }
    }
}

private struct SidebarTabRow: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab

    var body: some View {
        HStack(spacing: 8) {
            Button { browser.select(tab) } label: {
                HStack(spacing: 12) {
                    Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tab.title).lineLimit(1)
                        Text(tab.url?.host ?? (tab.isPrivate ? "Private Tab" : "New Tab"))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if browser.selectedTabID == tab.id {
                        Image(systemName: "checkmark").font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tab.title)
            .accessibilityValue(browser.selectedTabID == tab.id ? "Selected tab" : (tab.isPrivate ? "Private tab" : "Regular tab"))

            Button { browser.close(tab) } label: {
                Image(systemName: "xmark").font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close \(tab.title)")
        }
    }
}

struct TabGrid: View {
    @EnvironmentObject private var browser: BrowserStore
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(browser.tabs) { tab in
                    TabCard(tab: tab) {
                        browser.select(tab)
                        dismiss()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Tabs")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Tab", systemImage: "plus") {
                        browser.newTab()
                        dismiss()
                    }
                    Button("New Private Tab", systemImage: "hand.raised.fill") {
                        browser.newTab(isPrivate: true)
                        dismiss()
                    }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("New Tab Options")
            }
        }
    }
}

private struct TabCard: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    let select: () -> Void

    private var isSelected: Bool { browser.selectedTabID == tab.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(tab.isPrivate ? "Private" : "Tab", systemImage: tab.isPrivate ? "hand.raised.fill" : "globe")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button { browser.close(tab) } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(tab.title)")
                .accessibilityIdentifier("closeTab_\(tab.id)")
            }
            .padding(.leading, 14)

            Button(action: select) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.08))
                        if !tab.isPrivate, let snapshot = tab.snapshot {
                            Image(uiImage: snapshot)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                                .font(.title)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(alignment: .top, spacing: 6) {
                        Text(tab.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                        Spacer(minLength: 0)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(tab.url?.host ?? (tab.isPrivate ? "Private Tab" : "New Tab"))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tab.title)
            .accessibilityValue(isSelected ? "Selected tab" : (tab.isPrivate ? "Private tab" : "Regular tab"))
            .accessibilityIdentifier("selectTab_\(tab.id)")
            .contextMenu {
                Button("Duplicate", systemImage: "plus.square.on.square") { browser.duplicate(tab) }
                Button("Close", systemImage: "xmark", role: .destructive) { browser.close(tab) }
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
    }
}
