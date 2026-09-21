import Foundation

/// The shape of an invitation link, on both sides of the tap.
///
/// A link rather than a bare code, because a link is what people send each
/// other — and a universal link rather than an ordinary one, so that on an
/// iPhone with Shiori installed the tap opens the app on the invitation instead
/// of a web page telling them to go and find it themselves.
///
/// Three things have to agree for that to happen, and nothing warns when they
/// stop: the `applinks:` entry in `Shiori.entitlements`, the
/// `apple-app-site-association` the server publishes at that same host, and the
/// host below. When they disagree the link simply opens Safari again.
enum InvitationLink {
    /// The host serving both the invitation page and the association file. The
    /// API's own host: Shiori has no separate web property, and adding one to
    /// serve a single JSON file would be a second thing to deploy.
    static let host = "shiori-server-hvrhl6ox5q-ey.a.run.app"

    /// The scheme the invitation web page's "Ouvrir dans Shiori" button uses.
    /// A universal link cannot re-trigger from the page it already landed on,
    /// so that page needs a way back in that is not the link itself.
    static let scheme = "shiori"

    private static let path = "invite"

    /// The link to send. It opens the app when Shiori is installed, and the web
    /// page — which says what to do with the code — when it is not.
    static func url(code: String) -> URL {
        // The code alphabet is URL-safe, so there is nothing to escape.
        URL(string: "https://\(host)/\(path)/\(code)")!
    }

    /// The invitation code a tapped link carries, or nil when the URL is
    /// something else entirely.
    ///
    /// Both forms are read here: the universal link, where `invite` and the code
    /// are path segments, and `shiori://invite/<CODE>`, where `invite` is the
    /// host. The code is upper-cased because a link typed by hand, or lowered by
    /// a mail client, still names the same invitation.
    static func code(from url: URL) -> String? {
        let segments = url.pathComponents.filter { $0 != "/" }
        if url.scheme == scheme {
            guard url.host == path, let code = segments.first else { return nil }
            return normalized(code)
        }
        guard url.host == host, segments.count == 2, segments[0] == path else { return nil }
        return normalized(segments[1])
    }

    private static func normalized(_ code: String) -> String? {
        let upper = code.uppercased()
        // Eight characters and nothing else: a stray path is not an invitation,
        // and the server would only answer "unknown code" to it anyway.
        guard upper.count == 8, upper.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return upper
    }
}
