import SwiftUI

/// One saga as the Series tab draws it, and Découvrir with it: every mark on
/// the first line, in the top corner — the edition's language, where the
/// reader stands, their heart or stars — so the eye finds them in the same
/// place on every row; the covers underneath. The marks share that line only,
/// as on the library rows: the author below takes the whole width instead of
/// being squeezed beside them.
struct SeriesRow: View {
    let entry: FollowedSeries
    /// Off on the author's own page, where every row would repeat their name.
    var showsAuthor = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                // On the title's baseline, so the taller tag does not push the
                // author down.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    SagaName(name: entry.name, isAudio: entry.isAudio)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    marks
                }
                if showsAuthor, let author = entry.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            covers
        }
        .padding(.vertical, 2)
    }

    private var marks: some View {
        HStack(spacing: 6) {
            if let language = entry.language, language.isForeign {
                LanguageTag(language: language)
            }
            if let state = entry.state {
                SeriesStateLabel(state: state)
            }
            OpinionMark(
                rating: entry.opinion?.rating,
                isFavorite: entry.opinion?.favorite == true,
                font: .caption
            )
        }
        .font(.caption)
        .fixedSize()
    }

    /// Every volume of the cycle, in its order, as a cover: the owned ones with
    /// their status pinned on, the missing ones dimmed with their number, the
    /// announced ones fainter still under a clock with the day they come out
    /// beneath, nothing off the cycle — the reader's progress, and what they
    /// lack, read off the books themselves rather than off a bar. No titles:
    /// the saga screen is a tap away.
    private var covers: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(entry.strip.isEmpty ? entry.volumes.map { SeriesStripItem.owned($0) } : entry.strip) { item in
                    switch item {
                    case let .owned(volume):
                        BookCover(book: volume, width: coverWidth, showsFormatBadge: false)
                            .overlay(alignment: .topTrailing) {
                                ReadingStatusBadge(status: volume.status)
                                    .offset(x: 5, y: -5)
                            }
                    case let .missing(_, number, title, forthcoming, date, coverURL):
                        missing(
                            id: item.id,
                            number: number,
                            title: title,
                            forthcoming: forthcoming,
                            coverURL: coverURL
                        )
                        // Hung under the cover rather than stacked with it: a
                        // lazy stack sizes itself on the covers it drew first,
                        // and a line only some items carry was cut off.
                        .overlay(alignment: .bottom) {
                            if forthcoming, let date {
                                Text(verbatim: ReleaseDateText.short(date))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .offset(y: dateLine)
                            }
                        }
                    }
                }
            }
            // Room for the badges, which overhang the covers' corners and the
            // scroll view would otherwise clip, and for the dates under the
            // announced volumes.
            .padding(.top, 6)
            .padding(.trailing, 6)
            .padding(.bottom, hasDates ? dateLine : 0)
        }
        .scrollIndicators(.hidden)
        .accessibilityHidden(true)
    }

    private func missing(
        id: String,
        number: Int?,
        title: String,
        forthcoming: Bool,
        coverURL: URL?
    ) -> some View {
        BookCover(
            book: Book(
                id: id,
                title: title,
                authors: entry.author.map { [$0] } ?? [],
                coverURL: coverURL,
                status: .toRead
            ),
            width: coverWidth,
            showsFormatBadge: false
        )
        .opacity(forthcoming ? 0.2 : 0.35)
        .overlay(alignment: .bottom) {
            if let number {
                Text(verbatim: "\(number)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
        }
        // Where an owned volume pins its status: an announced one says it is
        // not out yet.
        .overlay(alignment: .topTrailing) {
            if forthcoming {
                Image(systemName: "clock")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(4)
            }
        }
    }

    private let coverWidth: CGFloat = 44
    private let dateLine: CGFloat = 16

    /// Whether any announced volume of the strip has a date to show under it.
    private var hasDates: Bool {
        entry.strip.contains {
            if case let .missing(_, _, _, forthcoming, date, _) = $0 { forthcoming && date != nil } else { false }
        }
    }
}
