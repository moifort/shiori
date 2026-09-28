import SwiftUI

/// What an author has for the reader in the format on screen, just under the
/// heading of their page, drawn as a saga's "Prochaines sorties" are:
/// "Annoncés" — the next work the web found and the editions of theirs the
/// reader awaits that are announced, the soonest first — then "Nouveautés" —
/// the works out in the last three months and the editions awaited now out,
/// the newest first. Drawn by the Découvrir domain, which looks the author up
/// on the web every week. A recording Audible confirmed opens on Audible; an
/// edition awaited opens its own page, as Découvrir opens it.
struct AuthorReleasesSection: View {
    let releases: AuthorReleases
    let author: String
    /// The author heard: the covers carry the headphones.
    let isAudio: Bool
    let onOpenAwaited: (AwaitedEdition) -> Void
    let onStopAwaiting: (AwaitedEdition) -> Void

    @Environment(\.openURL) private var openURL

    /// A work the web found or an edition the reader awaits, in one list.
    private enum Entry: Identifiable {
        case work(DiscoveredWork)
        case awaited(AwaitedEdition)

        var id: String {
            switch self {
            case let .work(work): "work-\(work.id)"
            case let .awaited(edition): "awaited-\(edition.id)"
            }
        }

        var day: String? {
            switch self {
            case let .work(work): work.date.map(ReleaseDateText.lastDay)
            case let .awaited(edition): edition.date.map(ReleaseDateText.lastDay)
            }
        }
    }

    private var announced: [Entry] {
        let entries = (releases.next.map { [Entry.work($0)] } ?? [])
            + releases.awaited.filter { $0.state == .announced }.map(Entry.awaited)
        return entries.sorted { lhs, rhs in
            guard let left = lhs.day else { return false }
            guard let right = rhs.day else { return true }
            return left < right
        }
    }

    private var out: [Entry] {
        let entries = releases.recent.map(Entry.work)
            + releases.awaited.filter { $0.state == .available }.map(Entry.awaited)
        return entries.sorted { ($0.day ?? "") > ($1.day ?? "") }
    }

    var body: some View {
        if !announced.isEmpty {
            Section {
                ForEach(announced) { row($0, isOut: false) }
            } header: {
                Text("Annoncés")
            }
            .accessibilityIdentifier("author-releases-next")
        }
        if !out.isEmpty {
            Section {
                ForEach(out) { row($0, isOut: true) }
            } header: {
                Text("Nouveautés")
            }
            .accessibilityIdentifier("author-releases-recent")
        }
    }

    @ViewBuilder
    private func row(_ entry: Entry, isOut: Bool) -> some View {
        switch entry {
        case let .work(work):
            if let audibleURL = work.audibleURL {
                Button { openURL(audibleURL) } label: { WorkReleaseRow(work: work, author: author, isAudio: isAudio, isOut: isOut) }
                    .tint(.primary)
                    .edgeToEdgeSeparator()
            } else {
                WorkReleaseRow(work: work, author: author, isAudio: isAudio, isOut: isOut)
                    .edgeToEdgeSeparator()
            }
        case let .awaited(edition):
            Button { onOpenAwaited(edition) } label: { AwaitedEditionReleaseRow(edition: edition) }
                .tint(.primary)
                .contextMenu {
                    if let url = edition.storeURL {
                        Button(edition.format.storeLabel, systemImage: "arrow.up.right.square") {
                            openURL(url)
                        }
                    }
                    Button("Ne plus suivre", systemImage: "bell.slash", role: .destructive) {
                        onStopAwaiting(edition)
                    }
                }
                .edgeToEdgeSeparator()
                .accessibilityIdentifier("author-awaited")
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

/// One piece of an author's news on Découvrir: a work the web found, or an
/// edition of theirs the reader awaits — drawn alike, the soonest to come or
/// the newest out first.
struct AuthorNewsItem: Identifiable {
    let id: String
    let title: String
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.
    let date: String?
    let coverURL: URL?
    let isComing: Bool

    init(work: DiscoveredWork) {
        id = "work-\(work.id)"
        title = work.title
        date = work.date
        coverURL = work.coverURL
        isComing = work.date.map { ReleaseDateText.isUpcoming($0) } ?? true
    }

    init(awaited: AwaitedEdition) {
        id = "awaited-\(awaited.id)"
        title = awaited.title
        date = awaited.date
        coverURL = awaited.coverURL
        isComing = awaited.state != .available
    }

    /// The works and editions awaited of one section of the shelf, in its
    /// order: the soonest first while announced, the undated last; the newest
    /// first once out.
    static func ordered(
        works: [DiscoveredWork],
        awaited: [AwaitedEdition],
        section: SagaReleasesSummary.Section
    ) -> [AuthorNewsItem] {
        let items = works.map(AuthorNewsItem.init(work:)) + awaited.map(AuthorNewsItem.init(awaited:))
        let day = { (item: AuthorNewsItem) in item.date.map(ReleaseDateText.lastDay) }
        switch section {
        case .upcoming:
            return items.sorted { lhs, rhs in
                guard let left = day(lhs) else { return false }
                guard let right = day(rhs) else { return true }
                return left < right
            }
        case .recent:
            return items.sorted { (day($0) ?? "") > (day($1) ?? "") }
        }
    }
}

/// An author's works announced or just out, and the editions of theirs the
/// reader awaits, as a strip of covers under their row on Découvrir's Authors
/// shelf: each with a clock and its day if it is still to come, a plus if it
/// is out — as the Series tab's strip marks the volumes the reader lacks. The
/// reader's own books are not repeated here.
struct AuthorWorksStrip: View {
    let items: [AuthorNewsItem]
    let author: String
    let isAudio: Bool

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(items) { work in
                    let coming = work.isComing
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
