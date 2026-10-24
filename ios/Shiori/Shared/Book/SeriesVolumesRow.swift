import SwiftUI

/// A book's saga as a row of its volumes, as the TV app lists a season's
/// episodes under the one playing: each cover with its number and where the
/// reader stands with it, the volume open on the page ringed. Only the volumes
/// the reader holds — the whole catalogue is the saga screen's, one tap away on
/// the header, and building it costs a model call this row must never make.
struct SeriesVolumesRow: View {
    let name: String
    /// The volumes held, in the order the saga runs.
    let volumes: [Book]
    /// The volume the page is about.
    let currentId: String
    let onOpenSeries: () -> Void
    let onOpenVolume: (Book) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RowHeader(
                title: LocalizedStringKey(name),
                detail: String(localized: "\(volumes.count) tomes"),
                action: onOpenSeries
            )
            .accessibilityIdentifier("book-series")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
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
        Button {
            if !isCurrent { onOpenVolume(volume) }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                BookCover(book: volume, width: 64, formatBadgeSize: 16)
                    .overlay {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(.primary, lineWidth: 2)
                                .padding(-4)
                        }
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(volume.series?.volume.map { String(localized: "Tome \($0)") } ?? volume.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(volume.status.label)
                        .font(.caption2)
                        .foregroundStyle(volume.status.tint)
                }
                .frame(width: 64, alignment: .leading)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
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
