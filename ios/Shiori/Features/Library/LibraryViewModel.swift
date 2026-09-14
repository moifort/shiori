import Foundation

/// Owns the library list: what is on screen, which shelf is filtered, and the
/// one in-flight load. Kept on the main actor because every property it exposes
/// is read by a view.
@MainActor
@Observable
final class LibraryViewModel {
    private(set) var sections: [LibrarySection] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// `nil` shows the whole library. The filter is applied server-side, before
    /// grouping, so a filtered saga loses its heading rather than showing an
    /// empty one.
    var filter: ReadingStatus? {
        didSet { if filter != oldValue { Task { await load() } } }
    }

    var isEmpty: Bool { sections.isEmpty && !isLoading && errorMessage == nil }

    /// How many books are on screen, across every section — what the empty and
    /// filtered states phrase themselves against.
    var bookCount: Int { sections.reduce(0) { $0 + $1.books.count } }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            sections = try await LibraryAPI.library(status: filter)
        } catch {
            // The list keeps whatever it was showing: replacing a good library
            // with an empty one because a refresh failed reads as data loss.
            errorMessage = ErrorPresenter.message(for: error)
        }
        isLoading = false
    }

    /// Applies a book the detail screen just changed, without refetching the
    /// whole library. A status change can move a book out of the current filter,
    /// so that case falls back to a reload rather than leaving a stale row.
    func apply(_ book: Book) async {
        if let filter, book.status != filter {
            await load()
            return
        }
        sections = sections.map { section in
            guard section.books.contains(where: { $0.id == book.id }) else { return section }
            return LibrarySection(
                seriesId: section.seriesId,
                seriesName: section.seriesName,
                books: section.books.map { $0.id == book.id ? book : $0 }
            )
        }
    }

    func remove(id: String) {
        sections = sections.compactMap { section in
            let kept = section.books.filter { $0.id != id }
            // A section whose last book was deleted must disappear with it,
            // otherwise the list keeps a heading over nothing.
            guard !kept.isEmpty else { return nil }
            return LibrarySection(
                seriesId: section.seriesId,
                seriesName: section.seriesName,
                books: kept
            )
        }
    }
}
