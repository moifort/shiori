import SwiftUI

/// A book of Découvrir the reader does not hold, opened as a book of the
/// library opens: the same sheet, the same page. It is not in the library, so
/// its record is built on the first opening — by anybody — as a saga's
/// catalogue is, which takes a few seconds once, and nothing after.
///
/// The page shows when it comes out in place of the reader's status, and adds
/// it to the pile, in its edition's language and at its place in the saga, on
/// one tap. Nothing enters the library without it.
struct BookPreviewView: View {
    let release: Release
    let edition: ReleaseEdition
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var close
    @State private var scanned: ScannedBook?
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var added = false
    @State private var errorMessage: String?
    @State private var openSeries: SeriesDestination?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Préparation de la fiche…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    BookPage(
                        book: book,
                        isSaving: false,
                        onSetStatus: { _ in },
                        onRate: {},
                        onToggleHidden: {},
                        onOpenSeries: {
                            openSeries = release.seriesId.map {
                                SeriesDestination(seriesId: $0, language: release.language)
                            }
                        },
                        onEditGenre: {},
                        onEditRecommendation: {},
                        preview: BookPreviewActions(
                            releaseDate: edition.date,
                            isAdding: isAdding,
                            isAdded: added,
                            onAdd: { Task { await add() } },
                            onDismiss: {
                                onDismiss()
                                close()
                            }
                        )
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { close() }
                }
            }
            .navigationDestination(item: $openSeries) {
                SeriesView(seriesId: $0.seriesId, language: $0.language)
            }
            .alert(
                "Ajout impossible",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: errorMessage ?? "")
            }
        }
        .task { await load() }
    }

    /// What the page draws: the record built for the book, placed where the
    /// release says — its saga and number, its edition's language — and, when
    /// it could not be built, what the release itself knows.
    private var book: Book {
        let fallback = release.book(edition)
        guard let scanned else { return fallback }
        return Book(
            id: fallback.id,
            title: scanned.title ?? edition.title,
            authors: scanned.authors.isEmpty ? fallback.authors : scanned.authors,
            format: fallback.format,
            publisher: scanned.publisher,
            firstPublishedIn: scanned.firstPublishedIn,
            synopsis: scanned.synopsis,
            genre: scanned.genre,
            subgenres: scanned.subgenres,
            pageCount: scanned.pageCount,
            isbn13: scanned.isbn13 ?? edition.isbn13,
            language: release.language,
            series: fallback.series,
            coverURL: scanned.coverURL ?? fallback.coverURL,
            status: .toRead
        )
    }

    private func load() async {
        defer { isLoading = false }
        do {
            scanned = try await DiscoverAPI.preview(releaseKey: release.key, title: edition.title)
        } catch {
            // The page still draws what the release knows: a preview is a
            // convenience, and the book can be added without it.
            _ = reportError(error)
        }
    }

    private func add() async {
        isAdding = true
        defer { isAdding = false }
        var draft = scanned?.asDraft ?? BookDraft(title: edition.title, authors: book.authors)
        draft.title = book.title
        draft.format = book.format
        draft.language = release.language
        draft.series = book.series
        draft.coverURL = book.coverURL
        draft.status = .toRead
        do {
            _ = try await BookAPI.add(draft)
            track(.bookAdded(source: .discover))
            added = true
        } catch {
            errorMessage = reportError(error)
        }
    }
}
