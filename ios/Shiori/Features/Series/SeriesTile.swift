import SwiftUI

/// One saga in the Series shelf's mosaic: its opening volume's cover with the
/// next two stacked behind it, so a saga reads as a pile rather than as one
/// book, and how many volumes the reader holds on the cover's foot — of how
/// many, once the catalogue says. Under it, the name and the marks the row
/// carries: the language, where the reader stands, their heart or stars.
struct SeriesTile: View {
    let entry: FollowedSeries
    let width: CGFloat

    /// How far each volume behind peeks over the one in front.
    private let step: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            pile
            VStack(alignment: .leading, spacing: 4) {
                SagaName(name: entry.name, isAudio: entry.isAudio)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                // As many marks as the column holds, the least telling
                // dropped first: the language, then the reader's judgement.
                ViewThatFits(in: .horizontal) {
                    marks(language: true, opinion: true)
                    marks(language: false, opinion: true)
                    marks(language: false, opinion: false)
                }
                .font(.caption2)
                .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func marks(language showsLanguage: Bool, opinion showsOpinion: Bool) -> some View {
        HStack(spacing: 4) {
            if showsLanguage, let language = entry.language, language.isForeign {
                LanguageTag(language: language)
            }
            if let state = entry.state {
                SeriesStateLabel(state: state)
            }
            if showsOpinion {
                OpinionMark(
                    rating: entry.opinion?.rating,
                    isFavorite: entry.opinion?.favorite == true
                )
            }
        }
        .fixedSize()
    }

    /// The first three volumes held, the first in front. Each one behind is
    /// narrower and raised, as a pile is seen from the front.
    private var pile: some View {
        let layers = Array(covers.prefix(3).enumerated())
        return ZStack(alignment: .top) {
            ForEach(layers.reversed(), id: \.element.id) { index, volume in
                BookCover(book: volume, width: width, showsFormatBadge: false)
                    .scaleEffect(1 - CGFloat(index) * 0.1, anchor: .top)
                    .offset(y: -CGFloat(index) * step)
                    .brightness(index == 0 ? 0 : -0.08 * Double(index))
            }
        }
        .overlay(alignment: .bottomTrailing) { count }
        // The room of a full pile on every tile, so the covers of a row stand
        // level whatever each one holds.
        .padding(.top, 2 * step)
    }

    /// The volumes held, in the order the saga runs. A saga without any on
    /// the row — a snapshot from before they were asked for — draws its name.
    private var covers: [Book] {
        guard entry.volumes.isEmpty else { return entry.volumes }
        return [Book(id: entry.seriesId, title: entry.name, authors: entry.author.map { [$0] } ?? [], status: .toRead)]
    }

    private var count: some View {
        Text(verbatim: countLabel)
            .font(.caption2.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: Capsule())
            .padding(5)
    }

    /// "3/7" when the catalogue knows volumes out that the reader lacks, "3"
    /// otherwise. The volumes announced but not out yet are not counted.
    private var countLabel: String {
        let published = entry.strip.filter {
            if case let .missing(_, _, _, forthcoming, _, _) = $0 { !forthcoming } else { true }
        }
        let held = published.filter { if case .owned = $0 { true } else { false } }.count
        return entry.isCatalogued && published.count > held
            ? "\(held)/\(published.count)"
            : "\(entry.ownedCount)"
    }
}
