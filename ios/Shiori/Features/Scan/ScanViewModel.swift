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
    }

    private(set) var step: Step = .camera
    private(set) var draft: BookDraft?
    /// The saga the scan resolved, shown on the review screen but not editable:
    /// membership is the server's answer, and letting the reader retype it here
    /// would create a saga that no catalogue knows.
    private(set) var seriesLabel: String?
    var error: String?
    var paywallShown = false
    private(set) var isSaving = false

    func capture(_ jpeg: Data) async {
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
            seriesLabel = scanned.seriesName.map { name in
                scanned.volumeNumber.map { "\(name) · Tome \($0)" } ?? name
            }
            step = .review
        } catch let APIError.domain(code, _) where code == "QUOTA_EXHAUSTED" {
            track(.scanBlockedByQuota)
            step = .camera
            paywallShown = true
        } catch {
            self.error = reportError(error)
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
        draft = nil
        seriesLabel = nil
        step = .camera
    }
}
