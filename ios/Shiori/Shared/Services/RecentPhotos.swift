import Photos
import SwiftUI

/// The last photos of the library, loaded for the add-a-book sheet so the
/// common case — a cover shot a minute ago — is one tap away
/// instead of a trip through the system picker.
@MainActor
@Observable
final class RecentPhotos {
    struct Photo: Identifiable {
        let id: String
        let thumbnail: UIImage
    }

    enum Access {
        /// Before the library answers: the strip shows its placeholders.
        case pending
        case granted
        case denied
    }

    private(set) var photos: [Photo] = []
    private(set) var access: Access = .pending

    private var assets: [String: PHAsset] = [:]
    private let manager = PHImageManager.default()

    /// Ten tiles cover the last minutes of shooting. Asking for more only
    /// delays the strip, and the system picker is one tap away for the rest.
    private static let limit = 10
    private static let thumbnailSide: CGFloat = 240

    func load() async {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else {
            access = .denied
            photos = []
            return
        }
        access = .granted
        let recent = fetchRecentAssets()
        assets = Dictionary(recent.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        var loaded: [Photo] = []
        for asset in recent {
            let side = Self.thumbnailSide
            guard let image = await requestImage(
                for: asset,
                targetSize: CGSize(width: side, height: side)
            ) else { continue }
            loaded.append(Photo(id: asset.localIdentifier, thumbnail: image))
            // Published as they arrive: the first tiles are usable while the
            // last ones are still coming down from iCloud.
            photos = loaded
        }
    }

    /// The full-size image behind a tile, fetched only once that tile is
    /// tapped: carrying ten originals would make the strip slow to appear.
    func fullImage(id: String) async -> UIImage? {
        guard let asset = assets[id] else { return nil }
        return await requestImage(for: asset, targetSize: PHImageManagerMaximumSize)
    }

    private func fetchRecentAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = Self.limit
        let result = PHAsset.fetchAssets(with: options)
        return result.objects(at: IndexSet(integersIn: 0 ..< result.count))
    }

    private func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            // The handler fires twice when a degraded image is available first:
            // the continuation is resumed on the final one, once.
            let gate = ResumeGate()
            let handler: @Sendable (UIImage?, [AnyHashable: Any]?) -> Void = { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                guard !isDegraded || isCancelled || image == nil else { return }
                guard gate.claim() else { return }
                continuation.resume(returning: image)
            }
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options,
                resultHandler: handler
            )
        }
    }
}

/// One-shot flag guarding a continuation resumed from a callback that the
/// Photos framework may call several times, from any thread.
private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
