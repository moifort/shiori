import SwiftUI

/// A saga on somebody's shelf: its name, author and genre. Among the
/// favourites it is drawn as the Series tab draws it, its volumes on the shelf
/// as a strip of covers underneath — owned volumes only, since the catalogue
/// is not something a friendship opens — with its genre, alone, in the top
/// corner.
/// Elsewhere it says it is hearted and how many of its volumes are on that
/// shelf. `accessory` sits beside the name and author, so the strip of covers
/// underneath still runs the full width of the row.
struct SagaRow<Accessory: View>: View {
    let saga: FriendSaga
    /// The favourites draw the covers in place of the volume count.
    var showsCovers = false
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    // The marks in the top corner, as on a book row: the heart is
                    // left out among the favourites, where every saga has one, and
                    // the genre takes its place.
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(saga.name).font(.body.weight(.medium)).lineLimit(2)
                        if let language = saga.language, language.isForeign {
                            LanguageTag(language: language)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            if showsCovers {
                                if let genre = saga.genre {
                                    RowChip(text: genre.label, tint: genre.tint)
                                }
                            } else {
                                if saga.favorite {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                        .accessibilityLabel(Text("Favori"))
                                }
                                Label("\(saga.ownedCount) tome(s)", systemImage: "books.vertical")
                                    .labelStyle(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption2)
                        .fixedSize()
                    }
                    if let author = saga.author {
                        Text(author).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !showsCovers, let genre = saga.genre {
                        Text([genre.label, saga.subgenre].compactMap(\.self).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                accessory
            }
            // Covers only: where the reader stands on each volume is theirs
            // to read on the saga itself, not on a list of what they love.
            if showsCovers, !saga.volumes.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(saga.volumes) { volume in
                            BookCover(book: volume, width: 44, showsFormatBadge: false)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
    }
}

extension SagaRow where Accessory == EmptyView {
    init(saga: FriendSaga, showsCovers: Bool = false) {
        self.init(saga: saga, showsCovers: showsCovers) { EmptyView() }
    }
}

/// One thing that moved on a shelf lately, top-aligned beside its cover: what
/// happened and when, then what it is, then who wrote it — and which volume,
/// for a book of a saga, whose covers the section draws underneath.
struct RecentActivityRow: View {
    let activity: RecentActivity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: cover, width: 36, showsFormatBadge: false)
            VStack(alignment: .leading, spacing: 2) {
                what.font(.caption).foregroundStyle(.secondary)
                Text(title).font(.subheadline.weight(.medium)).lineLimit(2)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recent-activity-row")
    }

    /// A book in progress is simply in progress; a finish and a heart say when.
    private var what: Text {
        let when = Text(activity.date, format: .relative(presentation: .named))
        return switch activity {
        case .reading: Text("En cours de lecture")
        case .finished: Text("Livre terminé \(when)")
        case .heartedSaga, .heartedBook: Text("Ajouté en favori \(when)")
        }
    }

    private var cover: Book {
        switch activity {
        case let .heartedSaga(saga, _): saga.coverBook
        case let .reading(entry, _), let .finished(entry, _), let .heartedBook(entry, _): entry.book
        }
    }

    private var title: String {
        switch activity {
        case let .heartedSaga(saga, _): saga.name
        case let .reading(entry, _), let .finished(entry, _), let .heartedBook(entry, _):
            entry.book.title
        }
    }

    private var detail: String? {
        switch activity {
        case let .heartedSaga(saga, _):
            saga.author
        case let .reading(entry, _), let .finished(entry, _), let .heartedBook(entry, _):
            [entry.book.authorLine, entry.book.series?.label].compactMap(\.self)
                .joined(separator: " · ")
        }
    }
}

extension FriendSaga {
    /// The saga as one cover: its first volume on the shelf, or the typographic
    /// placeholder made from its name and author.
    var coverBook: Book {
        volumes.first ?? Book(id: id, title: name, authors: author.map { [$0] } ?? [], status: .read)
    }
}
