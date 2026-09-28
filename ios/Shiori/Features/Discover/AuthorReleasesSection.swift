import SwiftUI

/// What an author has for the reader in the format on screen, just under the
/// heading of their page: the next work announced, then the ones out in the
/// last three months — drawn as a saga's "Prochaines sorties" are. Drawn by the
/// Découvrir domain, which looks the author up on the web every week. A
/// recording Audible confirmed opens on Audible.
struct AuthorReleasesSection: View {
    let releases: AuthorReleases
    let author: String
    /// The author heard: the covers carry the headphones.
    let isAudio: Bool

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let next = releases.next {
            Section {
                row(next, isOut: false)
            } header: {
                Text("Prochaines sorties")
            }
            .accessibilityIdentifier("author-releases-next")
        }
        if !releases.recent.isEmpty {
            Section {
                ForEach(releases.recent) { row($0, isOut: true) }
            } header: {
                Text("Nouveautés")
            }
            .accessibilityIdentifier("author-releases-recent")
        }
    }

    @ViewBuilder
    private func row(_ work: DiscoveredWork, isOut: Bool) -> some View {
        if let audibleURL = work.audibleURL {
            Button { openURL(audibleURL) } label: { WorkReleaseRow(work: work, author: author, isAudio: isAudio, isOut: isOut) }
                .tint(.primary)
                .edgeToEdgeSeparator()
        } else {
            WorkReleaseRow(work: work, author: author, isAudio: isAudio, isOut: isOut)
                .edgeToEdgeSeparator()
        }
    }
}

/// One work announced or just out, as a saga's next volume is drawn: its cover,
/// the saga it opens if any, its title, when it comes or came out in words,
/// and the calendar leaf on the trailing edge.
struct WorkReleaseRow: View {
    let work: DiscoveredWork
    let author: String
    let isAudio: Bool
    let isOut: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: Book(
                id: "release-\(work.id)",
                title: work.title,
                authors: [author],
                format: isAudio ? .audiobook : .book,
                coverURL: work.coverURL,
                status: .toRead
            ))
            VStack(alignment: .leading, spacing: 3) {
                if let saga {
                    Text(saga)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(work.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Group {
                    if let date = work.date {
                        Text(isOut ? ReleaseDateText.out(date) : ReleaseDateText.coming(date))
                    } else {
                        Text(isOut ? "Disponible" : "Annoncé")
                    }
                }
                .foregroundStyle(isOut ? Color.accentColor : .orange)
                .font(.subheadline.weight(.medium))
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if let date = work.date { ReleaseDateBadge(date: date) }
        }
        .padding(.vertical, 4)
    }

    /// "Dragon Blood · Tome 2", or the saga alone.
    private var saga: String? {
        guard let name = work.seriesName else { return nil }
        guard let volume = work.volume else { return name }
        return String(localized: "\(name) · Tome \(volume)")
    }
}

/// An author's works announced or just out as a strip of covers, under their
/// row on Découvrir's Authors shelf: each with a clock and its day if it is
/// still to come, a plus if it is out — as the Series tab's strip marks the
/// volumes the reader lacks. The reader's own books are not repeated here.
struct AuthorWorksStrip: View {
    let works: [DiscoveredWork]
    let author: String
    let isAudio: Bool

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(works) { work in
                    let coming = work.date.map { ReleaseDateText.isUpcoming($0) } ?? true
                    BookCover(
                        book: Book(
                            id: "release-\(work.id)",
                            title: work.title,
                            authors: [author],
                            format: isAudio ? .audiobook : .book,
                            coverURL: work.coverURL,
                            status: .toRead
                        ),
                        width: coverWidth,
                        showsFormatBadge: false
                    )
                    .overlay(alignment: .topTrailing) {
                        CoverBadge(systemImage: coming ? "clock" : "plus", tint: coming ? .orange : .accentColor)
                            .offset(x: 5, y: -5)
                    }
                    // Hung under the cover rather than stacked with it, as the
                    // Series tab hangs its dates: a lazy stack sizes itself on
                    // the covers it drew first. From the cover's leading edge:
                    // "nov. 2026" is wider than a cover, and centred the first
                    // one would be cut by the scroll view.
                    .overlay(alignment: .bottomLeading) {
                        if let date = work.date {
                            Text(verbatim: ReleaseDateText.short(date))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(coming ? Color.orange : .secondary)
                                .lineLimit(1)
                                .fixedSize()
                                .offset(y: dateLine)
                        }
                    }
                }
            }
            // Room for the badges, which overhang the covers' corners, and for
            // the dates under them.
            .padding(.top, 6)
            .padding(.trailing, 6)
            .padding(.bottom, dateLine)
        }
        .scrollIndicators(.hidden)
        .accessibilityHidden(true)
    }

    private let coverWidth: CGFloat = 44
    private let dateLine: CGFloat = 16
}
