import Foundation

@MainActor
final class BrowserStore: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var selectedTabID: BrowserTab.ID?
    @Published var showsTabs = false
    @Published var addressDraft = ""

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
    }

    func select(_ tab: BrowserTab) {
        selectedTabID = tab.id
        addressDraft = tab.url?.absoluteString ?? ""
        showsTabs = false
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty { newTab() }
        if selectedTabID == tab.id {
            selectedTabID = tabs[min(index, tabs.count - 1)].id
        }
    }

    func navigate() {
        guard let tab = selectedTab, let url = AddressResolver.resolve(addressDraft) else { return }
        tab.webView.load(URLRequest(url: url))
        addressDraft = url.absoluteString
    }

    func refreshAddress() {
        addressDraft = selectedTab?.url?.absoluteString ?? ""
    }
}

