import SwiftUI

/// "À suivre": the next volume of each saga in progress, held or not, as the
/// series screen and the pile both draw it. A cover opens its saga.
struct SeriesUpNextRail: View {
    let upNext: [(series: FollowedSeries, volume: FollowedSeries.NextVolume)]
    let onOpen: (FollowedSeries) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "À suivre", style: .inline).padding(.horizontal, 20)
            PosterRow(items: upNext.map(item)) { _ in }
                .contentMargins(.horizontal, 20, for: .scrollContent)
        }
        .accessibilityIdentifier("series-up-next")
    }

    private func item(_ entry: (series: FollowedSeries, volume: FollowedSeries.NextVolume)) -> PosterRow.Item {
        let open = { onOpen(entry.series) }
        switch entry.volume {
        case let .owned(book):
            let caption = book.series?.volume.map { String(localized: "Tome \($0)") } ?? book.title
            return PosterRow.Item(
                book: book,
                label: PosterLabel(caption: caption, marksReading: book.status == .reading),
                open: open
            )
        case let .missing(number, title, coverURL):
            let book = Book(
                id: "next-\(entry.series.id)",
                title: title,
                authors: entry.series.author.map { [$0] } ?? [],
                format: entry.series.isAudio ? .audiobook : .book,
                language: entry.series.language,
                coverURL: coverURL,
                status: .toRead
            )
            return PosterRow.Item(
                book: book,
                caption: number.map { String(localized: "Tome \($0)") } ?? title,
                open: open
            )
        }
    }
}
