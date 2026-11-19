import AVFoundation
import Foundation
import Observation

/// The Audible titles kept on the iPhone, so they play with no network.
///
/// A title starts downloading as soon as it starts playing, from the same
/// FairPlay stream, under a download licence: what is kept is Audible's
/// encrypted stream as AVFoundation stores it, and the content key the iPhone
/// was allowed to keep. Nothing is ever decrypted outside Apple's player. The
/// download goes once the book is finished.
@MainActor @Observable
final class AudibleDownloads {
    /// What a downloaded title needs to play with no licence at hand.
    struct Record: Codable, Equatable {
        let asin: String
        let contentReference: String
        let certificate: Data
        let duration: TimeInterval
        let chapters: [ListeningChapter]
        /// Where AVFoundation keeps the stream, relative to the home folder:
        /// the container moves between installs, the relative path does not.
        var relativePath: String?
        var isComplete = false
    }

    private var records: [String: Record]
    private var tasks: [String: AVAssetDownloadTask] = [:]
    /// How far each title under way has come, in whole percent.
    private var percents: [String: Int] = [:]
    @ObservationIgnored private var progressObservers: [String: NSKeyValueObservation] = [:]
    @ObservationIgnored private var session: AVAssetDownloadURLSession?
    @ObservationIgnored private let relay = DownloadRelay()

    static let sessionIdentifier = "com.polyforms.shiori.audible-downloads"

    init() {
        records = Self.loadRecords()
        relay.owner = self
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        session = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: relay,
            delegateQueue: .main
        )
        // Downloads that went on while the app was closed.
        session?.getAllTasks { [weak self] tasks in
            let found = tasks.compactMap { $0 as? AVAssetDownloadTask }
            Task { @MainActor in
                for task in found { if let asin = task.taskDescription { self?.follow(task, of: asin) } }
            }
        }
    }

    // MARK: - Reading

    /// Whether a title is wholly on the iPhone.
    func isDownloaded(_ asin: String) -> Bool { localAsset(asin) != nil }

    /// The title's stream on the iPhone, once wholly downloaded.
    func localAsset(_ asin: String) -> AVURLAsset? {
        guard let record = records[asin], record.isComplete,
              let path = record.relativePath else { return nil }
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return AVURLAsset(url: url)
    }

    func record(_ asin: String) -> Record? { records[asin] }

    /// How far a title still downloading has come, in whole percent; nil
    /// once it is wholly on the iPhone, or when nothing is under way.
    func downloadPercent(_ asin: String) -> Int? {
        guard tasks[asin] != nil, !isDownloaded(asin) else { return nil }
        return percents[asin] ?? 0
    }

    // MARK: - Downloading

    /// Download a title as it plays: the asset handed in is the one the
    /// player plays, so the two share what has already arrived.
    func download(_ asset: AVURLAsset, of playback: Playback, title: String) {
        let asin = playback.asin
        if let record = records[asin], record.isComplete || tasks[asin] != nil { return }
        records[asin] = Record(
            asin: asin,
            contentReference: playback.contentReference,
            certificate: playback.certificate,
            duration: playback.duration,
            chapters: playback.chapters
        )
        saveRecords()
        let configuration = AVAssetDownloadConfiguration(asset: asset, title: title)
        guard let task = session?.makeAssetDownloadTask(downloadConfiguration: configuration) else { return }
        task.taskDescription = asin
        follow(task, of: asin)
        task.resume()
    }

    /// Keep a task and the share of it already arrived, as the task's own
    /// progress counts it.
    private func follow(_ task: AVAssetDownloadTask, of asin: String) {
        tasks[asin] = task
        progressObservers[asin] = task.progress.observe(\.fractionCompleted, options: [.initial, .new]) {
            @Sendable [weak self] progress, _ in
            let percent = min(99, Int(progress.fractionCompleted * 100))
            Task { @MainActor in
                guard let self, self.tasks[asin] != nil, self.percents[asin] != percent else { return }
                self.percents[asin] = percent
            }
        }
    }

    private func forget(_ asin: String) {
        progressObservers.removeValue(forKey: asin)?.invalidate()
        percents[asin] = nil
    }

    /// Remove a title from the iPhone: the stream, the key and the record.
    func remove(_ asin: String) {
        tasks.removeValue(forKey: asin)?.cancel()
        forget(asin)
        if let path = records.removeValue(forKey: asin)?.relativePath {
            try? FileManager.default.removeItem(
                at: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(path)
            )
        }
        saveRecords()
        try? FileManager.default.removeItem(at: Self.keyURL(asin))
    }

    // MARK: - Keys

    /// The content key the iPhone was allowed to keep for a title.
    nonisolated static func storedKey(_ asin: String) -> Data? {
        try? Data(contentsOf: keyURL(asin))
    }

    nonisolated static func storeKey(_ key: Data, for asin: String) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? key.write(to: keyURL(asin), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: - Delegate

    fileprivate func willDownload(_ asin: String, to location: URL) {
        records[asin]?.relativePath = Self.relativePath(of: location)
        saveRecords()
    }

    fileprivate func finished(_ asin: String, at location: URL) {
        records[asin]?.relativePath = Self.relativePath(of: location)
        saveRecords()
    }

    fileprivate func completed(_ asin: String, error: Error?) {
        tasks[asin] = nil
        forget(asin)
        if let error {
            // A cancel is a removal, already done. Anything else, an expired
            // signed link above all, starts again at the next listening.
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            _ = reportError(error)
            if let path = records[asin]?.relativePath {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(path)
                )
            }
            records[asin] = nil
        } else {
            records[asin]?.isComplete = true
        }
        saveRecords()
    }

    // MARK: - Storage

    nonisolated private static var folder: URL {
        URL.applicationSupportDirectory.appendingPathComponent("AudibleDownloads", isDirectory: true)
    }

    nonisolated private static func keyURL(_ asin: String) -> URL {
        folder.appendingPathComponent("\(asin).key")
    }

    private static var indexURL: URL { folder.appendingPathComponent("index.json") }

    private static func relativePath(of location: URL) -> String {
        let home = NSHomeDirectory() + "/"
        return location.path.hasPrefix(home) ? String(location.path.dropFirst(home.count)) : location.path
    }

    private static func loadRecords() -> [String: Record] {
        guard let data = try? Data(contentsOf: indexURL),
              let records = try? JSONDecoder().decode([String: Record].self, from: data)
        else { return [:] }
        return records
    }

    private func saveRecords() {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: Self.indexURL, options: .atomic)
    }
}

/// AVFoundation's download callbacks, handed to the main actor. A separate
/// object because the session holds its delegate strongly.
private final class DownloadRelay: NSObject, AVAssetDownloadDelegate, @unchecked Sendable {
    @MainActor weak var owner: AudibleDownloads?

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, willDownloadTo location: URL) {
        guard let asin = assetDownloadTask.taskDescription else { return }
        MainActor.assumeIsolated { owner?.willDownload(asin, to: location) }
    }

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let asin = assetDownloadTask.taskDescription else { return }
        MainActor.assumeIsolated { owner?.finished(asin, at: location) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let asin = task.taskDescription else { return }
        MainActor.assumeIsolated { owner?.completed(asin, error: error) }
    }
}
