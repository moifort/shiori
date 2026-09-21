import SwiftUI

/// Everything the reader hearted, in one place: the sagas first, then the
/// books. No other screen gathers both — the library shows books, the series
/// tab shows sagas — and the dashboard tile that counts them together needs
/// somewhere to open.
///
/// Read from the two lists the app already has rather than from a query of
/// its own: a favourite is a flag on a row, and two requests the tabs make
/// anyway cost less than a third shape to keep in step.
struct FavoritesView: View {
    @State private var books: [Book] = []
    @State private var series: [FollowedSeries] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedBook: Book?
    @State private var openSeriesId: String?

    var body: some View {
        Group {
            if isLoading && books.isEmpty && series.isEmpty {
                ProgressView("Chargement de vos favoris...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, books.isEmpty, series.isEmpty {
                ContentUnavailableView {
                    Label("Favoris indisponibles", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    AsyncButton("Réessayer") { await load() }
                }
            } else if books.isEmpty && series.isEmpty {
                ContentUnavailableView {
                    Label("Aucun favori", systemImage: "heart")
                } description: {
                    Text("Un cœur sur un livre ou une série le range ici.")
                }
            } else {
                list
            }
        }
        .navigationTitle("Favoris")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $selectedBook) { book in
            BookView(
                bookId: book.id,
                onChanged: { _ in Task { await load() } },
                onDeleted: { _ in Task { await load() } }
            )
        }
        .navigationDestination(item: $openSeriesId) { SeriesView(seriesId: $0) }
    }

    private var list: some View {
        List {
            if !series.isEmpty {
                Section("Séries") {
                    ForEach(series) { entry in
                        Button {
                            openSeriesId = entry.seriesId
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(entry.name).font(.body.weight(.medium))
                                        if let language = entry.language, language.isForeign {
                                            LanguageTag(language: language)
                                        }
                                    }
                                    if let author = entry.author {
                                        Text(author).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 6) {
                                    if let state = entry.state {
                                        SeriesStateLabel(state: state)
                                    }
                                    OpinionMark(rating: entry.opinion?.rating, isFavorite: true, font: .caption)
                                }
                                .padding(.top, 2)
                            }
                            .padding(.vertical, 2)
                        }
                        .tint(.primary)
                    }
                }
            }
            if !books.isEmpty {
                Section("Livres") {
                    ForEach(books) { book in
                        Button {
                            selectedBook = book
                        } label: {
                            BookRow(
                                title: book.title,
                                authorLine: book.authorLine,
                                cover: book,
                                status: book.status,
                                rating: book.rating,
                                volumeLabel: book.series?.label,
                                genre: book.genre,
                                subgenre: book.subgenres.first,
                                format: book.format,
                                language: book.language,
                                isFavorite: book.favorite,
                                isHidden: book.hidden
                            )
                        }
                        .tint(.primary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let sections = LibraryAPI.library()
            async let followed = SeriesAPI.mySeries()
            books = try await sections.flatMap(\.books).filter(\.favorite)
            series = try await followed.filter { $0.opinion?.favorite == true }
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack { FavoritesView() }
}
