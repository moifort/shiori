#if DEBUG
import Apollo
import Foundation
import SwiftUI

/// The showcase on the reader's own iPhone, where `scripts/device-capture.sh`
/// takes the captures the simulator used to.
///
/// That iPhone is signed in to a real account, so a showcase run there must
/// leave it exactly as it found it: no request reaches the server with the
/// reader's token, the share extension's waiting item is left for the real
/// app, and every default a showcase screen writes is put back on the next
/// ordinary launch.
enum ShowcaseDevice {
    // MARK: - Launch arguments

    /// The tab the showcase opens on, named after `-showcase-tab`
    /// (`home`, `library`, `news`, `friends`): a capture without a tap.
    static var tab: TabSelection? {
        guard let name = value(after: "-showcase-tab") else { return nil }
        return switch name {
        case "home": .home
        case "library": .library
        case "news": .news
        case "friends": .friends
        default: nil
        }
    }

    /// The appearance the showcase draws in, named after
    /// `-showcase-appearance` (`light` or `dark`), whatever the phone is set to.
    static var colorScheme: ColorScheme? {
        switch value(after: "-showcase-appearance") {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    // MARK: - Covers

    /// Where `device-capture.sh` copies `screenshots/covers/` on the iPhone,
    /// which cannot read the Mac's disk as a simulator does.
    static let covers = URL.cachesDirectory.appending(path: "showcase-covers", directoryHint: .isDirectory)

    // MARK: - The reader's defaults

    /// The reader's own defaults, kept while a showcase run writes over them.
    private static var backup: URL {
        URL.applicationSupportDirectory.appending(path: "showcase-defaults-backup.plist")
    }

    /// Called first thing at launch. A showcase run saves the reader's defaults
    /// once, before any screen writes; the next ordinary launch puts them back
    /// as they were, and forgets the copy.
    static func preserveReaderDefaults() {
        guard let domain = Bundle.main.bundleIdentifier else { return }
        let defaults = UserDefaults.standard
        if Showcase.isOn {
            guard !FileManager.default.fileExists(atPath: backup.path) else { return }
            let saved = defaults.persistentDomain(forName: domain) ?? [:]
            guard let data = try? PropertyListSerialization.data(
                fromPropertyList: saved, format: .binary, options: 0
            ) else { return }
            try? FileManager.default.createDirectory(
                at: backup.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try? data.write(to: backup, options: .atomic)
        } else if let data = try? Data(contentsOf: backup),
            let saved = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any]
        {
            defaults.setPersistentDomain(saved, forName: domain)
            try? FileManager.default.removeItem(at: backup)
        }
    }
}

/// Refuses every request while the showcase runs: its screens answer from
/// fixtures, and on a signed-in iPhone a stray request would carry the
/// reader's token to the production server, or sign them out on a 401. First
/// in the chain, before the token is ever read.
struct ShowcaseNetworkGuard: HTTPInterceptor {
    struct Refused: Error {}

    func intercept(
        request: URLRequest,
        next: NextHTTPInterceptorFunction
    ) async throws -> HTTPResponse {
        if Showcase.isOn { throw Refused() }
        return try await next(request)
    }
}
#endif
