import SwiftUI

/// A book's saga as a row of its volumes, as the TV app lists a season's
/// episodes under the one playing: the saga's name over the row, the way to
/// its screen, then each volume as the home's pile sets its covers — the
/// number inside the cover's blurred foot — the volume open on the page
/// ringed. The volumes the reader lacks sit between theirs, dimmed, with the
/// series tab's "+" — or its clock and orange date for one announced — and
/// open the saga's screen, where they are added. They come from a catalogue
/// already built: building one costs a model call this row must never make.
struct SeriesVolumesRow: View {
    let name: String
    /// The volumes in the order the saga runs, held or lacking.
    let volumes: [SeriesStripItem]
    /// The volume the page is about.
    let currentId: String
    let onOpenSeries: () -> Void
    let onOpenVolume: (Book) -> Void

    /// The cover the row is scrolled to: the volume open on the page, deep
    /// in a long saga too.
    @State private var position = ScrollPosition(idType: String.self)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: LocalizedStringKey(name), style: .inline, action: onOpenSeries)
                .accessibilityIdentifier("book-series")
            ScrollView(.horizontal) {
                // Lazy: a long saga lacks a hundred volumes or more.
                LazyHStack(alignment: .top, spacing: 13) {
                    ForEach(volumes) { item in
                        switch item {
                        case let .owned(volume):
                            ownedCover(volume)
                        case let .missing(_, number, title, forthcoming, date, coverURL):
                            missingCover(
                                id: item.id,
                                number: number,
                                title: title,
                                forthcoming: forthcoming,
                                date: date,
                                coverURL: coverURL
                            )
                        }
                    }
                }
                .scrollTargetLayout()
                // Room for the ring around the current cover, for the badges
                // overhanging the lacking ones, and for the dates under the
                // announced ones.
                .padding(6)
                .padding(.bottom, hasDates ? dateLine : 0)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .padding(-6)
            .scrollPosition($position, anchor: .center)
            .onChange(of: volumes.map(\.id), initial: true) {
                position.scrollTo(id: currentId, anchor: .center)
            }
        }
    }

    private let dateLine: CGFloat = 22

    /// Whether any announced volume has a day to show under its cover.
    private var hasDates: Bool {
        volumes.contains {
            if case let .missing(_, _, _, forthcoming, date, _) = $0 { forthcoming && date != nil } else { false }
        }
    }

    @ViewBuilder
    private func ownedCover(_ volume: Book) -> some View {
        let isCurrent = volume.id == currentId
        let caption = Self.caption(of: volume)
        Button {
            if !isCurrent { onOpenVolume(volume) }
        } label: {
            // No "Audio" tag: on a recording's page, its saga is heard too.
            PosterCover(book: volume, caption: caption, showsAudioTag: false)
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: PosterCover.cornerRadius + 3, style: .continuous)
                            .strokeBorder(.primary, lineWidth: 2)
                            .padding(-4)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(volume.title), \(caption)"))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    /// A volume the reader lacks, dimmed as the series tab dims it: "+" when
    /// it is out, a clock and its day in orange when it is only announced.
    private func missingCover(
        id: String,
        number: Int?,
        title: String,
        forthcoming: Bool,
        date: String?,
        coverURL: URL?
    ) -> some View {
        let caption = number.map { String(localized: "Tome \($0)") } ?? title
        return Button(action: onOpenSeries) {
            PosterCover(
                    book: Book(id: id, title: title, authors: [], coverURL: coverURL, status: .toRead),
                    caption: caption,
                    showsAudioTag: false
                )
                .opacity(forthcoming ? 0.3 : 0.45)
                .overlay(alignment: .topTrailing) {
                    CoverBadge(
                        systemImage: forthcoming ? "clock" : "plus",
                        tint: forthcoming ? .orange : .accentColor
                    )
                    .offset(x: 5, y: -5)
                }
                // Hung under the cover rather than stacked with it: a lazy
                // stack sizes itself on the covers it drew first, and a line
                // only some items carry was cut off.
                .overlay(alignment: .bottom) {
                    if forthcoming, let date {
                        Text(verbatim: ReleaseDateText.short(date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                            .fixedSize()
                            .offset(y: dateLine)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(forthcoming ? "\(title), \(caption), à paraître" : "\(title), \(caption), à ajouter"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("book-series-missing")
    }

    /// "Tome 3", or the kind of a volume outside the numbering: "Préquelle".
    static func caption(of volume: Book) -> String {
        guard let series = volume.series else { return volume.title }
        guard let number = series.volume else { return series.kind.label }
        return String(localized: "Tome \(number)")
    }
}

#Preview {
    SeriesVolumesRow(
        name: "One Piece",
        volumes: (7...10).map { number in
            .owned(Book(
                id: "op-\(number)",
                title: "One Piece",
                authors: ["Eiichiro Oda"],
                format: .manga,
                series: SeriesMembership(id: "op", name: "One Piece", volume: number, kind: .main),
                status: number < 9 ? .read : number == 9 ? .reading : .toRead
            ))
        } + [
            .missing(key: "op-11", number: 11, title: "One Piece", forthcoming: false),
            .missing(key: "op-12", number: 12, title: "One Piece", forthcoming: true, date: "2026-12-03"),
        ],
        currentId: "op-9",
        onOpenSeries: {},
        onOpenVolume: { _ in }
    )
    .padding()
}
