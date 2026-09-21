import Foundation

/// Drives one pass through the camera: capture, scan, review, save.
///
/// A spent allowance is not an error. It is the one outcome that has its own
/// screen — the paywall — so it is matched on the server's `QUOTA_EXHAUSTED`
/// code rather than surfaced as a message the reader can only dismiss.
@MainActor
@Observable
final class ScanViewModel {
    enum Step: Equatable {
        case camera
        case analyzing
        case review
        case noResult
        /// The analysis itself did not come back — a timeout, a dropped
        /// connection, a model error — as opposed to answering that no book was
        /// there. The photo is kept, so the reader can run it again.
        case failed
    }

    private(set) var step: Step = .camera
    /// The shot being analysed, kept so a failed analysis can be run again on
    /// it, and so the waiting screen can show the reader their own cover under
    /// the scan rather than a generic loader.
    private(set) var capturedCover: Data?
    private(set) var draft: BookDraft?
    /// The saga the scan resolved, shown on the review screen but not editable:
    /// membership is the server's answer, and letting the reader retype it here
    /// would create a saga that no catalogue knows.
    private(set) var seriesLabel: String?
    /// Why the step is `.failed`, in the reader's words.
    private(set) var failure: String?
    /// The title being looked up, kept so a failed lookup can be run again.
    private(set) var typedTitle: String?
    var error: String?
    var paywallShown = false
    private(set) var isSaving = false

    func capture(_ jpeg: Data) async {
        capturedCover = jpeg
        step = .analyzing
        track(.scanStarted)
        do {
            let scanned = try await ScanAPI.scan(jpeg: jpeg)
            guard scanned.recognized, let title = scanned.title, !title.isEmpty else {
                track(.scanNoResult)
                step = .noResult
                return
            }
            track(.scanSucceeded)
            draft = scanned.asDraft
            seriesLabel = scanned.series.map { series in
                series.volume.map { "\(series.name) · Tome \($0)" } ?? series.name
            }
            step = .review
        } catch let APIError.domain(code, _) where code == "QUOTA_EXHAUSTED" {
            track(.scanBlockedByQuota)
            step = .camera
            paywallShown = true
        } catch {
            track(.scanFailed)
            failure = reportError(error)
            step = .failed
        }
    }

    /// Looks a book up from a title typed as remembered: the same proposal as
    /// a scan, with no cover to sweep on the waiting screen.
    func lookUp(title: String) async {
        capturedCover = nil
        typedTitle = title
        step = .analyzing
        track(.scanStarted)
        do {
            let scanned = try await ScanAPI.lookUp(title: title)
            guard scanned.recognized, let found = scanned.title, !found.isEmpty else {
                track(.scanNoResult)
                step = .noResult
                return
            }
            track(.scanSucceeded)
            draft = scanned.asDraft
            seriesLabel = scanned.series.map { series in
                series.volume.map { "\(series.name) · Tome \($0)" } ?? series.name
            }
            step = .review
        } catch let APIError.domain(code, _) where code == "QUOTA_EXHAUSTED" {
            track(.scanBlockedByQuota)
            step = .camera
            paywallShown = true
        } catch {
            track(.scanFailed)
            failure = reportError(error)
            step = .failed
        }
    }

    /// Runs the analysis again on the shot that failed. It spends nothing extra:
    /// a failed scan is not counted, and one that completed server-side after the
    /// app stopped waiting is answered from the cache.
    func retry() async {
        failure = nil
        if let jpeg = capturedCover {
            await capture(jpeg)
        } else if let typedTitle {
            await lookUp(title: typedTitle)
        } else {
            step = .camera
        }
    }

    /// Saves what the reader approved. The review screen is the safety net
    /// against a misread cover, so nothing reaches the library before this.
    func save(_ draft: BookDraft) async -> Book? {
        isSaving = true
        defer { isSaving = false }
        do {
            let book = try await BookAPI.add(draft)
            track(.bookAdded(source: .scan))
            return book
        } catch {
            self.error = reportError(error)
            return nil
        }
    }

    func retake() {
        capturedCover = nil
        typedTitle = nil
        failure = nil
        draft = nil
        seriesLabel = nil
        step = .camera
    }
}
