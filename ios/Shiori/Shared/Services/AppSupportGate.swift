import Foundation
import Observation

/// Blocks the app when the running build is older than the backend's minimum
/// supported iOS build (`GET /app-config`, public). Checked at launch and on
/// every return to the foreground, so a backend deploy that raises the floor
/// also catches apps that were already open. Fails open: a network or decoding
/// error never blocks the app.
@MainActor
@Observable
final class AppSupportGate {
    enum State: Equatable {
        case supported
        case updateRequired(appStoreURL: URL)
    }

    /// Defaults to `.supported` so launch never waits on the check; a blocked
    /// build may flash the regular UI for one round-trip before the gate closes.
    private(set) var state: State = .supported

    private struct AppConfig: Decodable {
        let minimumSupportedIOSBuild: Int
        let appStoreUrl: URL
    }

    func check() async {
        guard let build = Self.currentBuild else { return }
        let url = APIClient.shared.baseURL.appendingPathComponent("app-config")
        // Bypass URLCache: a stale floor would defeat the foreground re-check.
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else { return }
        state = build < config.minimumSupportedIOSBuild
            ? .updateRequired(appStoreURL: config.appStoreUrl)
            : .supported
    }

    /// `CFBundleVersion` is `git rev-list --count HEAD` at release time, so a
    /// plain integer comparison is enough — no marketing-version parsing.
    private static var currentBuild: Int? {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String).flatMap(Int.init)
    }
}
