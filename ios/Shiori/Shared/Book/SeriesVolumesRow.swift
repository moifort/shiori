import SwiftUI

/// A book's saga as a row of its volumes, as the TV app lists a season's
/// episodes under the one playing: the saga's name over the row, how many of
/// its volumes the reader holds against how many it has, then each cover with
/// its number and where the reader stands with it, the volume open on the page
/// ringed. Only the volumes the reader holds — the whole catalogue is the saga
/// screen's, one tap away on the header, and building it costs a model call
/// this row must never make.
struct SeriesVolumesRow: View {
    let name: String
    /// The volumes held, in the order the saga runs.
    let volumes: [Book]
    /// How many volumes the saga has, by its catalogue: nil while nobody has
    /// built it, and the header counts the volumes held alone.
    var volumeCount: Int? = nil
    /// The volume the page is about.
    let currentId: String
    let onOpenSeries: () -> Void
    let onOpenVolume: (Book) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RowHeader(title: LocalizedStringKey(name), detail: count, action: onOpenSeries)
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

    /// "1 sur 3 tomes" against the catalogue — the main volumes held, since
    /// a prequel sits off the spine the count runs along — else the volumes
    /// held alone.
    private var count: String {
        if let volumeCount {
            let held = volumes.filter { $0.series?.kind == .main }.count
            return String(localized: "\(held) sur \(volumeCount) tomes")
        }
        return volumes.count == 1 ? String(localized: "1 tome") : String(localized: "\(volumes.count) tomes")
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
                    // "T1": the number alone, the saga named over the row.
                    Text(volume.series?.volume.map { String(localized: "T\($0)") } ?? volume.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(volume.status.label.lowercased())
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
        volumeCount: 110,
        currentId: "op-9",
        onOpenSeries: {},
        onOpenVolume: { _ in }
    )
    .padding()
}
