import Foundation
import SwiftUI

struct RecentSite: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: URL
}

@MainActor
final class BrowserStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var selectedTabID: BrowserTab.ID?
    @Published var showsTabs = false
    @Published var showsSettings = false
    @Published var addressDraft = ""
    @Published private(set) var recentlyClosed: [(url: URL?, isPrivate: Bool)] = []
    @Published private(set) var recentSites: [RecentSite] = []

    let preferences = BrowserPreferences()
    private let contentBlocker = ContentBlocker()

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedTabID }
    }

    init() {
        newTab()
    }

    func newTab(isPrivate: Bool = false) {
        let tab = BrowserTab(isPrivate: isPrivate)
        tabs.append(tab)
        selectedTabID = tab.id
        addressDraft = ""
        contentBlocker.apply(enabled: preferences.blocksTrackers, to: tab.webView)
    }

    func select(_ tab: BrowserTab) {
        selectedTab?.captureSnapshot()
        selectedTabID = tab.id
        addressDraft = tab.url?.absoluteString ?? ""
        showsTabs = false
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tab.captureSnapshot()
        recentlyClosed.insert((tab.url, tab.isPrivate), at: 0)
        recentlyClosed = Array(recentlyClosed.prefix(10))
        tabs.remove(at: index)
        if tabs.isEmpty { newTab() }
        if selectedTabID == tab.id {
            selectedTabID = tabs[min(index, tabs.count - 1)].id
        }
    }

    func navigate() {
        guard let tab = selectedTab,
              let url = AddressResolver.resolve(addressDraft, searchEngine: preferences.searchEngine) else { return }
        tab.webView.load(URLRequest(url: url))
        addressDraft = url.absoluteString
    }

    func refreshAddress() {
        addressDraft = selectedTab?.url?.absoluteString ?? ""
    }

    func duplicate(_ tab: BrowserTab) {
        newTab(isPrivate: tab.isPrivate)
        guard let url = tab.url else { return }
        selectedTab?.webView.load(URLRequest(url: url))
    }

    func reopenLastClosedTab() {
        guard let closed = recentlyClosed.first else { return }
        recentlyClosed.removeFirst()
        newTab(isPrivate: closed.isPrivate)
        if let url = closed.url { selectedTab?.webView.load(URLRequest(url: url)) }
    }

    func moveTabs(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }

    func recordCurrentVisit() {
        guard let tab = selectedTab, !tab.isPrivate, let url = tab.url,
              let scheme = url.scheme, ["http", "https"].contains(scheme) else { return }
        recentSites.removeAll { $0.url.host == url.host }
        recentSites.insert(RecentSite(title: tab.title, url: url), at: 0)
        recentSites = Array(recentSites.prefix(6))
    }

    func open(_ url: URL) {
        addressDraft = url.absoluteString
        navigate()
    }

    func applyPrivacyPreferences() {
        for tab in tabs {
            contentBlocker.apply(enabled: preferences.blocksTrackers, to: tab.webView)
        }
    }
}
