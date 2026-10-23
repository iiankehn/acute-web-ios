import SwiftUI

struct StartPage: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var preferences: BrowserPreferences
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var favorites: FavoritesStore
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title3) private var tileIconSize: CGFloat = 44
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var searchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var brandLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
        : AnyLayout(HStackLayout(spacing: 18))
    }

    private var tileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 220 : 96), spacing: 12)]
    }

    private static let knownSymbols = [
        "wikipedia.org": "book.closed",
        "github.com": "chevron.left.forwardslash.chevron.right",
        "duckduckgo.com": "magnifyingglass"
    ]

    private func symbol(for site: SavedSite) -> String {
        guard let host = site.url?.host?.lowercased() else { return "globe" }
        return Self.knownSymbols[SitePrivacyStore.key(for: host)] ?? "star"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                brandLayout {
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
                        .foregroundStyle(.readableSecondary)
                        Text("by CORE")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.readableSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, horizontalSizeClass == .compact ? 8 : 40)
                .padding(.bottom, 4)

                HStack(spacing: 10) {
                    Image(systemName: browser.selectedTab?.isPrivate == true ? "hand.raised.fill" : "magnifyingglass")
                    .foregroundStyle(.secondary)
                    TextField("Search with \(preferences.searchEngine.title)", text: $browser.addressDraft)
                    .accessibilityLabel("Search with \(preferences.searchEngine.title)")
                    .focused($searchFocused)
                    .onChange(of: searchFocused) { _, focused in browser.isEditingAddress = focused }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .accessibilityIdentifier("startSearchField")
                    .submitLabel(.search)
                    .onSubmit {
                        searchFocused = false
                        browser.navigate()
                    }
                    .layoutPriority(1)
                    if !browser.addressDraft.isEmpty {
                        Button {
                            browser.addressDraft = ""
                            searchFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear Search")
                        .accessibilityIdentifier("clearStartSearch")
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
                                            Text(bookmark.title).font(.subheadline.weight(.semibold))
                                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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

                    if preferences.showsStartFavorites && !favorites.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Favorites")
                            LazyVGrid(columns: tileColumns, spacing: 12) {
                                ForEach(favorites.items) { favorite in
                                    Button {
                                        if let url = favorite.url { browser.open(url) }
                                    } label: {
                                        VStack(spacing: 12) {
                                            Image(systemName: symbol(for: favorite))
                                                .font(.title3.weight(.medium))
                                                .foregroundStyle(Color.accentColor)
                                                .frame(minWidth: min(tileIconSize, 88), minHeight: min(tileIconSize, 88))
                                                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                            Text(favorite.title).font(.subheadline.weight(.medium))
                                                .multilineTextAlignment(.center)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 84)
                                        .padding(12)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("favoriteTile")
                                    .contextMenu {
                                        Button("Remove from Favorites", systemImage: "star.slash", role: .destructive) {
                                            favorites.remove(favorite)
                                        }
                                    }
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
                                                Text(site.title).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                                                Text(site.url.host ?? site.url.absoluteString)
                                                .font(.caption).foregroundStyle(.secondary)
                                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
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
                    Label("Private tabs stay out of history and are not restored when you reopen Acute. Private tabs share sign-ins until all of them are closed. Downloaded files remain on this device until you delete them.", systemImage: "hand.raised.fill")
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
