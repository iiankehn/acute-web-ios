import SwiftUI

struct BrowserToolbar: View {
    @EnvironmentObject private var browser: BrowserStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var addressFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button { browser.selectedTab?.webView.goBack() } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(browser.selectedTab?.canGoBack != true)

            Button { browser.selectedTab?.webView.goForward() } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(browser.selectedTab?.canGoForward != true)

            HStack(spacing: 8) {
                Image(systemName: browser.selectedTab?.isPrivate == true ? "hand.raised.fill" : "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search or enter address", text: $browser.addressDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .focused($addressFocused)
                    .submitLabel(.go)
                    .onSubmit(browser.navigate)
                Button {
                    if browser.selectedTab?.isLoading == true {
                        browser.selectedTab?.webView.stopLoading()
                    } else {
                        browser.selectedTab?.webView.reload()
                    }
                } label: {
                    Image(systemName: browser.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .acuteGlass(cornerRadius: 22)

            if horizontalSizeClass == .compact {
                Button { browser.showsTabs = true } label: {
                    Image(systemName: "square.on.square")
                        .overlay(alignment: .center) {
                            Text("\(browser.tabs.count)").font(.system(size: 8, weight: .bold))
                        }
                }
            }

            Menu {
                Button("New Tab", systemImage: "plus") { browser.newTab() }
                Button("New Private Tab", systemImage: "hand.raised.fill") { browser.newTab(isPrivate: true) }
                Divider()
                if let url = browser.selectedTab?.url {
                    ShareLink(item: url)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 32, height: 32)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

private extension View {
    @ViewBuilder
    func acuteGlass(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.14), lineWidth: 0.5)
                }
        }
    }
}

