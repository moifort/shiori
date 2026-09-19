import SwiftUI
import WebKit

/// Amazon's own sign-in page, in a web view, watched for the redirect that
/// carries the authorization code back.
///
/// A web view rather than `ASWebAuthenticationSession`: the server hands out
/// three cookies that have to be planted before the page loads — they are what
/// makes the request look like the Audible iOS app, and without them Amazon
/// challenges the sign-in far more often. An authentication session shares
/// Safari's cookie jar and gives no way to seed it.
///
/// The password is typed into Amazon's page and never reaches this app, which is
/// the whole point of running the real page rather than a form of our own. The
/// data store is non-persistent so nothing of that session is left behind, and a
/// second attempt starts from a clean slate rather than from a half-signed-in one.
struct AmazonSignInWebView: UIViewRepresentable {
    let login: AudibleLogin
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(redirectURL: login.redirectURL, onCode: onCode)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Held here rather than read back from `webView.configuration`, which
        // hands out a copy: the cookies have to go into the store the web view
        // actually loads through.
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.start(webView, in: dataStore, with: login)
        return webView
    }

    /// Nothing to push: the sign-in is driven by the page itself, and reloading
    /// on every SwiftUI update would throw away whatever the reader has typed.
    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let redirectURL: String
        private let onCode: (String) -> Void
        /// Amazon can bounce through the landing URL more than once. The code is
        /// good for a single exchange, so it is handed over once and once only.
        private var hasAnsweredWithCode = false

        init(redirectURL: String, onCode: @escaping (String) -> Void) {
            self.redirectURL = redirectURL
            self.onCode = onCode
        }

        @MainActor
        func start(_ webView: WKWebView, in dataStore: WKWebsiteDataStore, with login: AudibleLogin) {
            guard let url = URL(string: login.url) else { return }
            Task {
                for cookie in login.cookies {
                    guard
                        let httpCookie = HTTPCookie(properties: [
                            .name: cookie.name,
                            .value: cookie.value,
                            .domain: cookie.domain,
                            .path: "/",
                            .secure: "TRUE",
                        ])
                    else { continue }
                    await dataStore.httpCookieStore.setCookie(httpCookie)
                }
                // Loaded only once every cookie is in the jar: a page that
                // started loading first would send the request without them.
                webView.load(URLRequest(url: url))
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url,
                let code = authorizationCode(in: url)
            else { return .allow }

            if !hasAnsweredWithCode {
                hasAnsweredWithCode = true
                onCode(code)
            }
            // Cancelled rather than allowed: the landing page has nothing to
            // show, and loading it would flash a blank Amazon page over a screen
            // that is already dismissing.
            return .cancel
        }

        private func authorizationCode(in url: URL) -> String? {
            guard url.absoluteString.hasPrefix(redirectURL) else { return nil }
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "openid.oa2.authorization_code" }?
                .value
        }
    }
}
