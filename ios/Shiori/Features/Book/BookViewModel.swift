import Foundation

/// Owns one book's screen. Every mutation returns the whole record, so the
/// model replaces its book wholesale rather than patching the field it asked
/// about — rating a book also marks it read, and only the server's answer knows
/// the full consequence.
@MainActor
@Observable
final class BookViewModel {
    private(set) var book: Book?
    /// The saga catalogue, loaded after the book and only when it belongs to
    /// one. Absent is an ordinary state: a book added by hand has no catalogue,
    /// and neither does one whose catalogue call failed on the scan.
    private(set) var series: BookSeries?
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    /// Set while a mutation is in flight, so the screen can disable its controls
    /// without blanking the content underneath.
    private(set) var isSaving = false

    private let bookId: String

    init(bookId: String) {
        self.bookId = bookId
    }

    /// The other volumes of the saga — what the recommendations section shows.
    /// Zero-cost: the catalogue is already loaded, so this is a filter, not a
    /// call.
    var otherVolumes: [Volume] {
        guard let series, let owned = book?.series else { return [] }
        return (series.spine + series.relatedWorks).filter { $0.number != owned.volume }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            book = try await BookAPI.book(id: bookId)
            await loadSeries()
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    private func loadSeries() async {
        guard let seriesId = book?.series?.id else {
            series = nil
            return
        }
        // A missing catalogue must not fail the screen: the book is what the
        // reader came for, and the recommendations section simply does not show.
        series = try? await SeriesAPI.series(id: seriesId)
    }

    func setStatus(_ status: ReadingStatus) async {
        await mutate { try await BookAPI.setStatus(id: self.bookId, status: status) }
    }

    func rate(_ stars: Int) async {
        await mutate { try await BookAPI.rate(id: self.bookId, stars: stars) }
    }

    func setNote(_ note: String?) async {
        await mutate { try await BookAPI.setNote(id: self.bookId, note: note) }
    }

    func setHidden(_ hidden: Bool) async {
        await mutate { try await BookAPI.setHidden(id: self.bookId, hidden: hidden) }
    }

    func delete() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await BookAPI.delete(id: bookId)
            return true
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    /// Adds a volume the reader does not own, from the recommendations section.
    /// No photo and no AI call, so it spends no scan.
    func addVolume(_ volume: Volume) async -> Book? {
        guard let series else { return nil }
        isSaving = true
        defer { isSaving = false }
        do {
            let added = try await BookAPI.add(
                BookDraft(title: volume.title, authors: [series.author])
            )
            track(.bookAdded(source: .series))
            return added
        } catch {
            errorMessage = reportError(error)
            return nil
        }
    }

    private func mutate(_ operation: @escaping () async throws -> Book) async {
        isSaving = true
        defer { isSaving = false }
        do {
            book = try await operation()
        } catch {
            errorMessage = reportError(error)
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
