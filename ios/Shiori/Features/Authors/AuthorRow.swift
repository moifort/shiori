import SwiftUI

/// One author as the Authors shelf draws them, on the pattern of a friend's row
/// in Partagé: the avatar on the left, the name with what the reader made of
/// them in the top corner, the books and sagas in figures underneath. Then every
/// book of theirs as a cover, across the whole width of the row, each with its
/// reading status pinned on; then the saga the reader is in with them, measured
/// as the Home dashboard's "Séries en cours" measures one. A finished saga
/// shows its full bar, so every row that has a saga has the same shape.
struct AuthorRow: View {
    let author: FollowedAuthor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            covers
            if let saga = author.saga {
                sagaProgress(saga)
            }
        }
        .padding(.vertical, 2)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(author.initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.15), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(author.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    mark
                }
                Text(figures)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// What ranks the author here: their hearts when they have any, else the
    /// mean of their stars.
    @ViewBuilder
    private var mark: some View {
        Group {
            if author.favoriteCount > 0 {
                Label {
                    Text(verbatim: "\(author.favoriteCount)")
                } icon: {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                }
                .accessibilityLabel(Text("\(author.favoriteCount) favoris"))
            } else if let rating = author.averageRating {
                Label {
                    Text(rating, format: .number.precision(.fractionLength(1)))
                } icon: {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
                .accessibilityLabel(Text("Note moyenne \(rating.formatted(.number.precision(.fractionLength(1))))"))
            }
        }
        .labelStyle(.caption)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize()
    }

    /// "14 livres, 3 séries" — the sagas left out when there are none.
    private var figures: String {
        let books = author.bookCount == 1
            ? String(localized: "1 livre")
            : String(localized: "\(author.bookCount) livres")
        switch author.seriesCount {
        case 0: return books
        case 1: return String(localized: "\(books), 1 série")
        default: return String(localized: "\(books), \(author.seriesCount) séries")
        }
    }

    /// Every book of theirs as a cover, newest shelved first, with its status
    /// pinned on as the Series tab pins it.
    private var covers: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(author.books) { book in
                    BookCover(book: book, width: coverWidth, showsFormatBadge: false)
                        .overlay(alignment: .topTrailing) {
                            ReadingStatusBadge(status: book.status)
                                .offset(x: 5, y: -5)
                        }
                }
            }
            // Room for the badges, which overhang the covers' corners and the
            // scroll view would otherwise clip.
            .padding(.top, 6)
            .padding(.trailing, 6)
        }
        .scrollIndicators(.hidden)
        .accessibilityHidden(true)
    }

    private func sagaProgress(_ saga: AuthorSaga) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(saga.series.name).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                OpinionMark(
                    rating: saga.series.opinion?.rating,
                    isFavorite: saga.series.opinion?.favorite == true
                )
                Text(verbatim: "\(saga.readCount)/\(saga.totalCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(saga.readCount), total: Double(max(1, saga.totalCount)))
                .tint(DashboardPalette.series)
        }
        .accessibilityElement(children: .combine)
    }

    private let coverWidth: CGFloat = 44
}
