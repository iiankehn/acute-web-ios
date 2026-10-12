import SwiftUI

private enum TabBrowseScope: String, CaseIterable, Identifiable {
    case all = "All", regular = "Regular", privateTabs = "Private"
    var id: String { rawValue }

    @MainActor func includes(_ tab: BrowserTab) -> Bool {
        switch self {
        case .all: return true
        case .regular: return !tab.isPrivate
        case .privateTabs: return tab.isPrivate
        }
    }
}

@MainActor private func matchesTabSearch(_ tab: BrowserTab, query: String) -> Bool {
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty || tab.title.localizedStandardContains(text)
        || (tab.url?.absoluteString.localizedStandardContains(text) == true)
}

private struct EmptyTabSearch: View {
    @Binding var query: String
    @Binding var searchPresented: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Matching Tabs", systemImage: "magnifyingglass")
        } description: {
            Text("Try another title or address, or clear your search to see your open tabs.")
        } actions: {
            Button {
                query = ""
                searchPresented = false
            } label: {
                Text("Clear Search").frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("clearTabSearch")
        }
    }
}

struct TabSidebar: View {
    @EnvironmentObject private var browser: BrowserStore
    @State private var closingScope: TabCloseScope?
    @State private var query = ""
    @State private var searchPresented = false

    private var visibleTabs: [BrowserTab] {
        browser.tabs.filter { matchesTabSearch($0, query: query) }
    }

    var body: some View {
        List {
            ForEach(visibleTabs) { tab in
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
            .moveDisabled(!query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .listStyle(.sidebar)
        .navigationTitle("Acute Web")
        .searchable(text: $query, isPresented: $searchPresented, prompt: "Search tabs")
        .overlay {
            if visibleTabs.isEmpty {
                EmptyTabSearch(query: $query, searchPresented: $searchPresented)
            }
        }
        .modifier(TabClosingConfirmation(scope: $closingScope))
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { browser.showsLibrary = true } label: {
                    Label("Library", systemImage: "books.vertical")
                }
                Spacer()
                Button { browser.showsDownloads = true } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
            }
            ToolbarItem(placement: .primaryAction) { TabManagementMenu(scope: $closingScope) }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            Button { browser.select(tab) } label: {
                HStack(spacing: 12) {
                    Image(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tab.title).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
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
            .accessibilityAddTraits(browser.selectedTabID == tab.id ? .isSelected : [])
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
    @State private var closingScope: TabCloseScope?
    @State private var query = ""
    @State private var searchPresented = false
    @State private var browseScope: TabBrowseScope = .all
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 160), spacing: 16)]
    }

    private var visibleTabs: [BrowserTab] {
        browser.tabs.filter { browseScope.includes($0) && matchesTabSearch($0, query: query) }
    }

    private var scopePicker: some View {
        Picker("Tab Filter", selection: $browseScope) {
            ForEach(TabBrowseScope.allCases) { scope in Text(scope.rawValue).tag(scope) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("tabScopePicker")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if dynamicTypeSize.isAccessibilitySize {
                    Picker("Tab Filter", selection: $browseScope) {
                        ForEach(TabBrowseScope.allCases) { scope in Text(scope.rawValue).tag(scope) }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                } else {
                    scopePicker
                }
                HStack {
                    Text("\(visibleTabs.count) of \(browser.tabs.count) open")
                    Spacer()
                    Label("\(browser.tabs.filter { $0.isPrivate }.count) private", systemImage: "hand.raised")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                if visibleTabs.isEmpty {
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EmptyTabSearch(query: $query, searchPresented: $searchPresented)
                    } else {
                        ContentUnavailableView(
                            browseScope == .privateTabs ? "No Private Tabs" : "No Regular Tabs",
                            systemImage: browseScope == .privateTabs ? "hand.raised" : "square.on.square",
                            description: Text("Create a tab with New Tab Options or choose All to see your other tabs.")
                        )
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visibleTabs) { tab in
                            TabCard(tab: tab) {
                                browser.select(tab)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Tabs")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $query, isPresented: $searchPresented,
                    placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tabs")
        .modifier(TabClosingConfirmation(scope: $closingScope))
        .toolbar {
            ToolbarItem(placement: .primaryAction) { TabManagementMenu(scope: $closingScope) }
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

private struct TabManagementMenu: View {
    @EnvironmentObject private var browser: BrowserStore
    @Binding var scope: TabCloseScope?

    var body: some View {
        Menu {
            ForEach(TabCloseScope.allCases) { target in
                Button(target.title, role: .destructive) { scope = target }
                    .disabled(!browser.tabs.contains { target.includes($0) })
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Tab Actions")
    }
}

private struct TabClosingConfirmation: ViewModifier {
    @EnvironmentObject private var browser: BrowserStore
    @Binding var scope: TabCloseScope?

    func body(content: Content) -> some View {
        content.alert(scope?.title ?? "Close Tabs", isPresented: Binding(
            get: { scope != nil }, set: { if !$0 { scope = nil } }
        ), presenting: scope) { target in
            Button(target.title, role: .destructive) { browser.closeTabs(target) }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text((target == .regular ? "Regular tabs can be reopened from the recent closed-tab list." : "Closed private tabs cannot be reopened. A regular start page opens if no tabs remain.") + " This applies to all matching open tabs, including tabs hidden by search or filters.")
        }
    }
}

private struct TabCard: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                        } else if tab.isPrivate {
                            Image(systemName: "hand.raised.fill")
                                .font(.title)
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Image("AcuteMark").resizable().scaledToFit()
                                .frame(width: 56, height: 56)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(alignment: .top, spacing: 6) {
                        Text(tab.title).font(.subheadline.weight(.semibold))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityValue(isSelected ? "Selected tab" : (tab.isPrivate ? "Private tab" : "Regular tab"))
            .accessibilityIdentifier("selectTab_\(tab.id)")
            .contextMenu {
                Button("Duplicate", systemImage: "plus.square.on.square") { browser.duplicate(tab) }
                Button("Close", systemImage: "xmark", role: .destructive) { browser.close(tab) }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
    }
}
