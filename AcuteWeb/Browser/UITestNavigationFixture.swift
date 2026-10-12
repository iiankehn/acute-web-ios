#if DEBUG
import WebKit

// Real local document navigations exercise WebKit's back/forward list without networking.
final class UITestNavigationFixture: NSObject, WKURLSchemeHandler {
    static let scheme = "acute-ui-fixture"
    static let launchArgument = "-acuteUITestHistoryPage"

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let isNext = url.path == "/next"
        let title = isNext ? "Second fixture page" : "First fixture page"
        let link = isNext ? "" : "<a href='acute-ui-fixture://pages/next'>Next fixture page</a>"
        let html = """
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <title>\(title)</title><body><h1>\(title)</h1>\(link)</body>
            """
        let data = Data(html.utf8)
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: "text/html",
                                            expectedContentLength: data.count, textEncodingName: "utf-8"))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
#endif
