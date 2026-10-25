import SwiftUI

/// A book's saga as a row of its volumes, as the TV app lists a season's
/// episodes under the one playing: the saga's name over the row, the way to
/// its screen, then each volume as the home's pile sets its covers — the
/// number inside the cover's blurred foot — the volume open on the page
/// ringed. Only the volumes the reader holds: the whole
/// catalogue is the saga screen's, one tap away on the header, and building
/// it costs a model call this row must never make.
struct SeriesVolumesRow: View {
    let name: String
    /// The volumes held, in the order the saga runs.
    let volumes: [Book]
    /// The volume the page is about.
    let currentId: String
    let onOpenSeries: () -> Void
    let onOpenVolume: (Book) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: LocalizedStringKey(name), style: .inline, action: onOpenSeries)
                .accessibilityIdentifier("book-series")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 13) {
                    ForEach(volumes) { volume in
                        volumeCover(volume)
                    }
                }
                // Room for the ring around the current cover.
                .padding(4)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .padding(-4)
        }
    }

    @ViewBuilder
    private func volumeCover(_ volume: Book) -> some View {
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
        volumes: (7...12).map { number in
            Book(
                id: "op-\(number)",
                title: "One Piece",
                authors: ["Eiichiro Oda"],
                format: .manga,
                series: SeriesMembership(id: "op", name: "One Piece", volume: number, kind: .main),
                status: number < 9 ? .read : number == 9 ? .reading : .toRead
            )
        },
        currentId: "op-9",
        onOpenSeries: {},
        onOpenVolume: { _ in }
    )
    .padding()
}
