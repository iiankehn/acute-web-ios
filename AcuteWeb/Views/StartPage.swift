import SwiftUI

struct StartPage: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var preferences: BrowserPreferences
    @ObservedObject var bookmarks: BookmarkStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
                VStack(spacing: 12) {
                    Image("AcuteMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text("Acute Web")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("by CORE")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        Text(browser.selectedTab?.isPrivate == true ? "Private browsing" : "The web, in focus.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, horizontalSizeClass == .compact ? 12 : 36)
                .padding(.bottom, 4)

                HStack(spacing: 10) {
                    Image(systemName: browser.selectedTab?.isPrivate == true ? "hand.raised.fill" : "magnifyingglass")
                    .foregroundStyle(.secondary)
                    TextField("Search with \(preferences.searchEngine.title)", text: $browser.addressDraft)
                    .focused($searchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .accessibilityIdentifier("startSearchField")
                    .submitLabel(.search)
                    .onSubmit {
                        searchFocused = false
                        browser.navigate()
                    }
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 56)
                .acuteGlass(cornerRadius: 22)

                if browser.selectedTab?.isPrivate != true {
                    if preferences.showsStartBookmarks && !bookmarks.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Bookmarks")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                                ForEach(bookmarks.items.prefix(8)) { bookmark in
                                    Button {
                                        if let url = bookmark.url { browser.open(url) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Image(systemName: "bookmark.fill").font(.title2)
                                            Text(bookmark.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                        .padding()
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if preferences.showsStartFavorites {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Favorites")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                                ForEach(favorites) { favorite in
                                    Button {
                                        if let url = URL(string: favorite.address) { browser.open(url) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Image(systemName: favorite.symbol).font(.title2)
                                            Text(favorite.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                        .padding()
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if preferences.showsStartRecentSites && !browser.recentSites.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
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
            .padding(.horizontal, horizontalSizeClass == .compact ? 20 : 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(colors: backgroundColors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        }
        .foregroundStyle(.primary)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
    }

    private var backgroundColors: [Color] {
        colorScheme == .dark
        ? [.black, Color(red: 0.02, green: 0.10, blue: 0.15)]
        : [Color(red: 0.95, green: 0.98, blue: 1.0), .white]
    }
}
