import Foundation

/// Resolves the Firebase Functions endpoint that hosts the GraphQL API.
/// All HTTP transport now happens through GraphQLClient (Apollo iOS).
struct APIClient: Sendable {
    static let shared = APIClient()

    private static let serverURLKey = "serverURL"
    // The deployed Cloud Function. A wrong value here does not fail loudly: any
    // *.a.run.app host resolves, so the app reaches Google and gets a 404 that
    // reads like a broken API rather than a wrong address.
    private static let defaultServerURL = "https://shiori-server-hvrhl6ox5q-ey.a.run.app"

    var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: Self.serverURLKey)
            ?? Self.defaultServerURL
        return URL(string: stored) ?? URL(string: Self.defaultServerURL)!
    }
}
