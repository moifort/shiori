import SwiftUI

/// A saga on somebody's shelf: its name, author and genre. Among the
/// favourites it is drawn as the Series tab draws it, its volumes on the shelf
/// as a strip of covers underneath — owned volumes only, since the catalogue
/// is not something a friendship opens — with its genre, alone, in the top
/// corner.
/// Elsewhere it says it is hearted and how many of its volumes are on that
/// shelf.
struct SagaRow: View {
    let saga: FriendSaga
    /// The favourites draw the covers in place of the volume count.
    var showsCovers = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

/// One thing that moved on a shelf lately: its cover, what it is, what
/// happened to it, and how long ago. A volume says which one it is; its saga
/// is drawn underneath by the section.
struct RecentActivityRow: View {
    let activity: RecentActivity

    var body: some View {
        HStack(spacing: 12) {
            BookCover(book: cover, width: 36, showsFormatBadge: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).lineLimit(2)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(activity.date, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("recent-activity-row")
    }

    private var cover: Book {
        switch activity {
        case let .heartedSaga(saga, _): saga.coverBook
        case let .reading(entry, _), let .finished(entry, _): entry.book
        }
    }

    private var title: String {
        switch activity {
        case let .heartedSaga(saga, _): saga.name
        case let .reading(entry, _), let .finished(entry, _): entry.book.title
        }
    }

    /// What happened, then what tells it apart: the volume for a saga being
    /// read, the author otherwise.
    private var detail: String {
        switch activity {
        case let .heartedSaga(saga, _):
            [String(localized: "Série ajoutée aux favoris"), saga.author].compactMap(\.self)
                .joined(separator: " · ")
        case let .reading(entry, _):
            [String(localized: "En cours de lecture"), entry.book.series?.label ?? entry.book.authorLine]
                .joined(separator: " · ")
        case let .finished(entry, _):
            [String(localized: "Livre terminé"), entry.book.series?.label ?? entry.book.authorLine]
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
