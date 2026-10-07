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
    /// The record the reader already keeps of the book under review, if any.
    private(set) var ownedCopy: Book?
    /// Why the step is `.failed`, in the reader's words.
    private(set) var failure: String?
    /// The title being looked up, kept so a failed lookup can be run again.
    private(set) var typedTitle: String?
    /// The shared page being looked up, kept for the same reason.
    private(set) var sharedLink: String?
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
            ownedCopy = scanned.ownedCopy
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

    /// Looks a book up from a page the reader shared from Safari or a bookshop.
    func lookUp(link: String) async {
        capturedCover = nil
        typedTitle = nil
        sharedLink = link
        step = .analyzing
        track(.scanStarted)
        do {
            let scanned = try await ScanAPI.lookUp(link: link)
            guard scanned.recognized, let found = scanned.title, !found.isEmpty else {
                track(.scanNoResult)
                step = .noResult
                return
            }
            track(.scanSucceeded)
            draft = scanned.asDraft
            ownedCopy = scanned.ownedCopy
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
            ownedCopy = scanned.ownedCopy
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
        } else if let sharedLink {
            await lookUp(link: sharedLink)
        } else {
            step = .camera
        }
    }

    /// Saves what the reader approved. The review screen is the safety net
    /// against a misread cover, so nothing reaches the library before this.
    /// Adds the book, then awaits the editions asked for. A saga the reader
    /// renamed on the review is not the one the scan keyed, so the book is
    /// added without it and then filed by name, as the edit form files one:
    /// the server joins the saga the reader holds by that name, or keys a new
    /// one.
    func save(_ draft: BookDraft, series placement: SeriesPlacement? = nil) async -> Book? {
        isSaving = true
        defer { isSaving = false }
        do {
            var added = draft
            if placement != nil { added.series = nil }
            var book = try await BookAPI.add(added)
            track(.bookAdded(source: .scan))
            if let placement {
                var correction = BookCorrection()
                correction.series = .set(placement)
                do {
                    book = try await BookAPI.update(id: book.id, correction: correction)
                } catch {
                    // The book is in: only its saga is missing, which its
                    // sheet can file afterwards.
                    _ = reportError(error)
                }
            }
            if draft.rating > 0 || draft.favorite {
                do {
                    // The stars first: the heart then keeps them.
                    if draft.rating > 0 {
                        book = try await BookAPI.rate(id: book.id, stars: draft.rating)
                    }
                    if draft.favorite {
                        book = try await BookAPI.setFavorite(id: book.id, favorite: true)
                    }
                } catch {
                    // The book is in: only its stars or its heart are missing,
                    // which its page gives in one tap.
                    _ = reportError(error)
                }
            }
            return book
        } catch {
            self.error = reportError(error)
            return nil
        }
    }

    func retake() {
        capturedCover = nil
        typedTitle = nil
        sharedLink = nil
        failure = nil
        draft = nil
        ownedCopy = nil
        step = .camera
    }
}
