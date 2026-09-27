import SwiftUI

struct StartPage: View {
    @EnvironmentObject private var browser: BrowserStore
    @FocusState private var searchFocused: Bool

    private struct FavoriteSite: Identifiable {
        let title: String
        let address: String
        let symbol: String
        var id: String { address }
    }

    private let favorites: [FavoriteSite] = [
        FavoriteSite(title: "Wikipedia", address: "https://wikipedia.org", symbol: "book.closed"),
        FavoriteSite(title: "GitHub", address: "https://github.com", symbol: "chevron.left.forwardslash.chevron.right"),
        FavoriteSite(title: "DuckDuckGo", address: "https://duckduckgo.com", symbol: "magnifyingglass")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Acute Web")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                    Text(browser.selectedTab?.isPrivate == true ? "Private browsing" : "The web, in focus.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Image(systemName: browser.selectedTab?.isPrivate == true ? "hand.raised.fill" : "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search with \(browser.preferences.searchEngine.title)", text: $browser.addressDraft)
                        .focused($searchFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit(browser.navigate)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 56)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                }

                if browser.selectedTab?.isPrivate != true {
                    if !browser.bookmarks.items.isEmpty {
                        sectionTitle("Bookmarks")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 12)], spacing: 12) {
                            ForEach(browser.bookmarks.items.prefix(8)) { bookmark in
                                Button {
                                    if let url = bookmark.url { browser.open(url) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 18) {
                                        Image(systemName: "bookmark.fill").font(.title2)
                                        Text(bookmark.title).font(.headline).lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                                    .padding()
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    sectionTitle("Favorites")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 12)], spacing: 12) {
                        ForEach(favorites) { favorite in
                            Button {
                                if let url = URL(string: favorite.address) { browser.open(url) }
                            } label: {
                                VStack(alignment: .leading, spacing: 18) {
                                    Image(systemName: favorite.symbol).font(.title2)
                                    Text(favorite.title).font(.headline)
                                }
                                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !browser.recentSites.isEmpty {
                        sectionTitle("This Session")
                        VStack(spacing: 8) {
                            ForEach(browser.recentSites) { site in
                                Button { browser.open(site.url) } label: {
                                    HStack {
                                        Image(systemName: "globe")
                                        VStack(alignment: .leading) {
                                            Text(site.title).lineLimit(1)
                                            Text(site.url.host ?? site.url.absoluteString)
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                    }
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Label("Private tabs do not appear in session history and use a non-persistent WebKit data store.", systemImage: "hand.raised.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(colors: [.black, Color(red: 0.02, green: 0.10, blue: 0.15)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .foregroundStyle(.white)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(.secondary)
    }
}
