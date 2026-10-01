import ImageIO
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
/// at will, and is cleared with the snapshots when the session ends. It holds
/// each cover as it was served; the memory half holds it decoded at the size
/// it is drawn, so a mosaic's narrow tiles keep every cover on screen in
/// memory rather than a few full-size ones.
///
/// A download, once started, runs to the end and lands on disk even when the
/// tile that asked for it scrolls away: a fast scroll through the mosaic
/// otherwise threw away every cover it passed, and paid for each again on the
/// way back.
enum CoverImages {
    /// NSCache is thread-safe by contract, though not marked `Sendable`.
    private nonisolated(unsafe) static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Counted in decoded bytes: some fifteen hundred mosaic tiles, or a
        // few dozen covers drawn full width.
        cache.totalCostLimit = 200 * 1024 * 1024
        return cache
    }()

    private static let downloads = Downloads()

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

    /// The image already in memory at that size, read synchronously so a row
    /// redrawn with a fresh link shows its cover on the very first frame.
    static func cached(_ url: URL, maxPixelSize: Int? = nil) -> UIImage? {
        memory.object(forKey: memoryKey(key(for: url), maxPixelSize))
    }

    /// The image from memory, else from disk, else from the network — decoded
    /// off the main thread, its longest side brought down to `maxPixelSize`
    /// when one is given.
    static func load(_ url: URL, maxPixelSize: Int? = nil) async throws -> UIImage {
        let key = key(for: url)
        let memoryKey = memoryKey(key, maxPixelSize)
        if let image = memory.object(forKey: memoryKey) { return image }
        let file = file(for: key)
        let data: Data
        if let stored = await Task.detached(operation: { try? Data(contentsOf: file) }).value {
            data = stored
        } else {
            data = try await downloads.data(from: url, to: file)
        }
        guard let image = await Task.detached(operation: { decoded(data, maxPixelSize: maxPixelSize) }).value
        else { throw URLError(.cannotDecodeContentData) }
        memory.setObject(image, forKey: memoryKey, cost: image.decodedBytes)
        return image
    }

    /// Fetches to disk, a few at a time, the covers of rows not drawn yet, so
    /// they show at once when scrolled to. Skips the ones already stored.
    static func prefetch(_ urls: [URL]) {
        let pending = urls.map { ($0, file(for: key(for: $0))) }
        Task.detached(priority: .utility) {
            let missing = pending.filter { !FileManager.default.fileExists(atPath: $0.1.path()) }
            await withTaskGroup(of: Void.self) { group in
                for (index, (url, file)) in missing.enumerated() {
                    if index >= 4 { await group.next() }
                    // A cover that cannot be fetched now is asked again when drawn.
                    group.addTask { _ = try? await downloads.data(from: url, to: file) }
                }
            }
        }
    }

    /// Forget every cover. Called when the session ends, with the snapshots:
    /// the next account must not be handed the last reader's photos.
    static func clear() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: folder)
    }

    private static func memoryKey(_ key: String, _ maxPixelSize: Int?) -> NSString {
        "\(key)@\(maxPixelSize ?? 0)" as NSString
    }

    private static func file(for key: String) -> URL {
        folder.appending(path: fileName(for: key))
    }

    /// Decoded straight to the size asked for: the full image is never held
    /// in memory on the way.
    private static func decoded(_ data: Data, maxPixelSize: Int?) -> UIImage? {
        guard let maxPixelSize else { return UIImage(data: data)?.preparingForDisplay() }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map(UIImage.init(cgImage:))
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

/// The downloads in flight, one per cover however many tiles ask for it at
/// once. Each runs in a task of its own, which a caller that gives up waiting
/// does not cancel.
private actor Downloads {
    private var running: [URL: Task<Data, Error>] = [:]

    func data(from url: URL, to file: URL) async throws -> Data {
        if let task = running[file] { return try await task.value }
        let task = Task<Data, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            // A cover that cannot be written costs a download next time, nothing more.
            try? FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try? data.write(to: file, options: .atomic)
            return data
        }
        running[file] = task
        defer { running[file] = nil }
        return try await task.value
    }
}

private extension UIImage {
    /// What the image weighs once decoded, which is what the memory cache holds.
    var decodedBytes: Int {
        cgImage.map { $0.bytesPerRow * $0.height } ?? 0
    }
}

extension EnvironmentValues {
    /// The longest side, in pixels, the covers below are drawn at: set where
    /// covers are small, as on a mosaic's tiles, so each is decoded no larger.
    /// Nil decodes them whole.
    @Entry var coverMaxPixelSize: Int? = nil
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
    @Environment(\.coverMaxPixelSize) private var maxPixelSize

    var body: some View {
        Group {
            switch phase ?? CoverImages.cached(url, maxPixelSize: maxPixelSize).map(Phase.loaded) {
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
        .task(id: "\(CoverImages.key(for: url))@\(maxPixelSize ?? 0)") {
            if let image = CoverImages.cached(url, maxPixelSize: maxPixelSize) {
                phase = .loaded(image)
                return
            }
            phase = nil
            do {
                phase = .loaded(try await CoverImages.load(url, maxPixelSize: maxPixelSize))
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed
            }
        }
    }
}
