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
                        SagaName(name: saga.name, isAudio: saga.isAudio)
                            .font(.body.weight(.medium))
                            .lineLimit(2)
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
