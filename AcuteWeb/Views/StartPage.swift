import SwiftUI

struct StartPage: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var preferences: BrowserPreferences
    @ObservedObject var bookmarks: BookmarkStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var searchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var tileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 220 : 96), spacing: 12)]
    }

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
                HStack(spacing: 18) {
                    Image("AcuteMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Acute Web")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(browser.selectedTab?.isPrivate == true ? "Private browsing" : "The web, in focus.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        Text("by CORE")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, horizontalSizeClass == .compact ? 8 : 40)
                .padding(.bottom, 4)

                HStack(spacing: 10) {
                    Image(systemName: browser.selectedTab?.isPrivate == true ? "hand.raised.fill" : "magnifyingglass")
                    .foregroundStyle(.secondary)
                    TextField("Search with \(preferences.searchEngine.title)", text: $browser.addressDraft)
                    .accessibilityLabel("Search with \(preferences.searchEngine.title)")
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
                            HStack {
                                sectionTitle("Bookmarks")
                                Spacer()
                                Button("See All") { browser.showsLibrary = true }
                                    .font(.subheadline.weight(.medium))
                                    .frame(minHeight: 44)
                                    .accessibilityLabel("Open Bookmarks")
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 220 : 140), spacing: 12)], spacing: 12) {
                                ForEach(bookmarks.items.prefix(8)) { bookmark in
                                    Button {
                                        if let url = bookmark.url { browser.open(url) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Image(systemName: "bookmark.fill")
                                                .foregroundStyle(Color.accentColor)
                                            Text(bookmark.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                            Text(bookmark.url?.host ?? "")
                                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                                        .padding()
                                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if preferences.showsStartFavorites {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Favorites")
                            LazyVGrid(columns: tileColumns, spacing: 12) {
                                ForEach(favorites) { favorite in
                                    Button {
                                        if let url = URL(string: favorite.address) { browser.open(url) }
                                    } label: {
                                        VStack(spacing: 12) {
                                            Image(systemName: favorite.symbol)
                                                .font(.title3.weight(.medium))
                                                .foregroundStyle(Color.accentColor)
                                                .frame(width: 44, height: 44)
                                                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                            Text(favorite.title).font(.subheadline.weight(.medium)).lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 84)
                                        .padding(12)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
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
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundStyle(Color.accentColor)
                                                .frame(width: 32, height: 32)
                                            VStack(alignment: .leading) {
                                                Text(site.title).lineLimit(1)
                                                Text(site.url.host ?? site.url.absoluteString)
                                                .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                        }
                                        .frame(minHeight: 44)
                                        .padding(12)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                } else {
                    Label("Private tabs stay out of history and are not restored when you reopen Acute. Downloaded files remain on this device until you delete them.", systemImage: "hand.raised.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
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
        Text(title).font(.headline).accessibilityAddTraits(.isHeader)
    }

    private var backgroundColors: [Color] {
        colorScheme == .dark
        ? [Color(uiColor: .systemGroupedBackground), Color(red: 0.03, green: 0.06, blue: 0.08)]
        : [Color(uiColor: .systemGroupedBackground), Color(red: 0.95, green: 0.97, blue: 0.99)]
    }
}
