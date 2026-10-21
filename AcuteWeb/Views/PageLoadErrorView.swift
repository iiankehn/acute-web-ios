import SwiftUI

struct PageLoadErrorView: View {
    @EnvironmentObject private var browser: BrowserStore
    @ObservedObject var tab: BrowserTab
    let message: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 72, height: 72)
                    .background(Color.accentColor.opacity(0.08), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unable to Load Page")
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    if let host = (tab.lastRequestedURL ?? tab.url)?.host {
                        Text(host).font(.headline).textSelection(.enabled)
                            .accessibilityIdentifier("failedPageHost")
                    }
                    Text(message).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if tab.navigationFailure?.offersInsecureRetry(for: tab.lastRequestedURL) == true {
                        Text("If this site doesn’t support HTTPS, you can open it without encryption. Information you send could be seen by others on the network.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { recoveryActions }
                        .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 12) { recoveryActions }
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("pageLoadError")
    }

    @ViewBuilder private var recoveryActions: some View {
        Button { browser.retryNavigation() } label: {
            Label("Try Again", systemImage: "arrow.clockwise").frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(tab.lastRequestedURL == nil)
        Button { browser.focusAddress() } label: {
            Label("Edit Address", systemImage: "pencil").frame(minHeight: 44)
        }
        .accessibilityIdentifier("editFailedAddress")
        Button { browser.showStartPage() } label: {
            Label("Start Page", systemImage: "house").frame(minHeight: 44)
        }
        .accessibilityIdentifier("failedPageStartPage")
        if tab.navigationFailure?.offersInsecureRetry(for: tab.lastRequestedURL) == true {
            Button { browser.retryOverHTTP() } label: {
                Label("Open Without HTTPS", systemImage: "lock.open").frame(minHeight: 44)
            }
            .accessibilityHint("Loads the page over an unencrypted connection")
            .accessibilityIdentifier("failedPageInsecureRetry")
        }
    }
}
