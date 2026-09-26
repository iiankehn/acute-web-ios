import SwiftUI

struct TabSidebar: View {
    @EnvironmentObject private var browser: BrowserStore

    var body: some View {
        List(browser.tabs) { tab in
            Button { browser.select(tab) } label: {
                HStack {
                    Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                    VStack(alignment: .leading) {
                        Text(tab.title).lineLimit(1)
                        Text(tab.url?.host ?? (tab.isPrivate ? "Private" : "New Tab"))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if browser.selectedTabID == tab.id {
                        Circle().fill(.cyan).frame(width: 6, height: 6)
                    }
                }
            }
            .swipeActions {
                Button(role: .destructive) { browser.close(tab) } label: { Label("Close", systemImage: "xmark") }
            }
        }
        .navigationTitle("Acute Web")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Tab") { browser.newTab() }
                    Button("New Private Tab") { browser.newTab(isPrivate: true) }
                } label: { Image(systemName: "plus") }
            }
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
                    Button {
                        browser.select(tab)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                                .font(.title2)
                            Spacer()
                            Text(tab.title).font(.headline).lineLimit(2)
                            Text(tab.url?.host ?? "New Tab").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .contextMenu {
                        Button("Close", role: .destructive) { browser.close(tab) }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Tabs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { browser.newTab(); dismiss() } label: { Image(systemName: "plus") }
            }
        }
    }
}

