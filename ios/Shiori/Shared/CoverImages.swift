import SwiftUI
import UIKit

/// The covers already fetched, in memory and on disk, keyed by what the image
/// *is* rather than by the URL that served it. A photographed cover comes
/// through a URL the server signs for one hour, so every answer names the same
/// photo differently: keyed by URL, each refresh fetched it again and the row
/// blinked through its grey loading state, and a relaunch over last session's
/// snapshot showed the initials of every expired link before the fresh ones
/// arrived.
///
/// The disk half lives in the caches directory, which the system may reclaim
/// at will, and is cleared with the snapshots when the session ends.
enum CoverImages {
    /// NSCache is thread-safe by contract, though not marked `Sendable`.
    private nonisolated(unsafe) static let memory = NSCache<NSString, UIImage>()

    private static var folder: URL {
        URL.cachesDirectory.appending(path: "covers", directoryHint: .isDirectory)
    }

    /// The URL without its signature: a signed Cloud Storage link keeps the
    /// object in its path and the expiry in `X-Goog-*` query items. Any other
    /// query is kept, since it may name the image itself.
    static func key(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url.absoluteString }
        let kept = components.queryItems?.filter { !$0.name.lowercased().hasPrefix("x-goog-") }
        components.queryItems = kept?.isEmpty == true ? nil : kept
        return components.string ?? url.absoluteString
    }

    /// The image already in memory, read synchronously so a row redrawn with a
    /// fresh link shows its cover on the very first frame.
    static func cached(_ url: URL) -> UIImage? {
        memory.object(forKey: key(for: url) as NSString)
    }

    /// The image from memory, else from disk, else from the network — decoded
    /// off the main thread.
    static func load(_ url: URL) async throws -> UIImage {
        let key = key(for: url)
        if let image = memory.object(forKey: key as NSString) { return image }
        let file = folder.appending(path: fileName(for: key))
        if let image = await Task.detached(operation: { decoded(try? Data(contentsOf: file)) }).value {
            memory.setObject(image, forKey: key as NSString)
            return image
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let image = await Task.detached(operation: { decoded(data) }).value else {
            throw URLError(.cannotDecodeContentData)
        }
        memory.setObject(image, forKey: key as NSString)
        // A cover that cannot be written costs a download next launch, nothing more.
        Task.detached {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
        }
        return image
    }

    /// Forget every cover. Called when the session ends, with the snapshots:
    /// the next account must not be handed the last reader's photos.
    static func clear() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: folder)
    }

    private static func decoded(_ data: Data?) -> UIImage? {
        data.flatMap(UIImage.init(data:))?.preparingForDisplay()
    }

    /// A stable, filesystem-safe name: an FNV-1a hash of the key, so a long URL
    /// never exceeds the name limit.
    private static func fileName(for key: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in key.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}

/// A remote cover drawn from `CoverImages`: the cached image on the first
/// frame when there is one, `loading` while it is fetched, `fallback` when it
/// cannot be — an expired link with nothing cached, or a publisher cover that
/// has since vanished from its source.
struct CoverImage<Loading: View, Fallback: View>: View {
    let url: URL
    @ViewBuilder let loading: () -> Loading
    @ViewBuilder let fallback: () -> Fallback

    private enum Phase {
        case loaded(UIImage)
        case failed
    }

    @State private var phase: Phase?

    var body: some View {
        Group {
            switch phase ?? CoverImages.cached(url).map(Phase.loaded) {
            case let .loaded(image):
                Image(uiImage: image).resizable().scaledToFill()
            case .failed:
                fallback()
            case nil:
                loading()
            }
        }
        // Keyed on the image, not the link: a refresh that re-signs the same
        // photo does not start over.
        .task(id: CoverImages.key(for: url)) {
            if let image = CoverImages.cached(url) {
                phase = .loaded(image)
                return
            }
            phase = nil
            do {
                phase = .loaded(try await CoverImages.load(url))
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed
            }
        }
    }
}
