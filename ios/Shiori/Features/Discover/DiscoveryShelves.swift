import Foundation

/// What each shelf of Découvrir lists, read off the feed: pure, so the page
/// draws it and a test checks it without a view.
extension DiscoveryFeed {
    /// The sagas of both formats, read and heard side by side: the tab draws
    /// them mixed, the headphones on a recording's cover telling them apart.
    /// Nil until neither format was ever loaded.
    var sagas: [SagaDiscovery]? {
        guard !rows.isEmpty else { return nil }
        return ReleaseFormat.allCases.flatMap { rows[$0] ?? [] }
    }

    /// The sagas with a volume announced, for the Books shelf: the soonest out
    /// first, a year alone read as its last day so "2027" comes after
    /// "2027-02-19", and the volumes nobody found a date for last.
    var upcoming: [SagaDiscovery] {
        (sagas ?? [])
            .filter { $0.releases.next != nil }
            .sorted { lhs, rhs in
                let left = lhs.releases.next?.date.map(ReleaseDateText.lastDay)
                let right = rhs.releases.next?.date.map(ReleaseDateText.lastDay)
                guard left != right else {
                    return lhs.series.name.localizedStandardCompare(rhs.series.name) == .orderedAscending
                }
                guard let left else { return false }
                guard let right else { return true }
                return left < right
            }
    }

    /// Every volume just out of the sagas, for the Books shelf, each with its
    /// saga: the newest first.
    var recentVolumes: [DiscoveryVolume] {
        (sagas ?? [])
            .flatMap { saga in saga.recent.map { DiscoveryVolume(saga: saga, volume: $0) } }
            .sorted { ($0.volume.date ?? "", $0.volume.number) > ($1.volume.date ?? "", $1.volume.number) }
    }

    /// The sagas with a volume just out, for the Series shelf: the newest out
    /// first.
    var recentSagas: [SagaDiscovery] {
        (sagas ?? [])
            .filter { !$0.recent.isEmpty }
            .sorted { ($0.recent.first?.date ?? "") > ($1.recent.first?.date ?? "") }
    }

    /// "Nouveautés séries", on the Books shelf: the volumes just out, the
    /// newest first, then the next of each saga announced, the soonest first.
    var seriesNews: [DiscoveryVolume] {
        let coming = upcoming.compactMap { saga in
            saga.releases.next.map { DiscoveryVolume(saga: saga, volume: $0) }
        }
        return recentVolumes + coming
    }

    /// The authors of both formats, one row per author: a writer read and
    /// heard is one face on the shelf, their news in both formats under it.
    private var authorNews: [AuthorNews] {
        var order: [String] = []
        var parts: [String: [AuthorNews.Part]] = [:]
        for format in ReleaseFormat.allCases {
            for row in authors[format] ?? [] {
                if parts[row.author.id] == nil { order.append(row.author.id) }
                parts[row.author.id, default: []].append(AuthorNews.Part(format: format, row: row))
            }
        }
        return order.compactMap { id in parts[id].map(AuthorNews.init) }
    }

    /// The authors with a work announced, an edition awaited announced or a
    /// saga's volume announced, for the Authors shelf: the soonest out first,
    /// as the Books shelf orders its volumes.
    var upcomingAuthors: [AuthorNews] {
        authorNews
            .filter(\.hasComing)
            .sorted { lhs, rhs in
                let left = lhs.soonestComing
                let right = rhs.soonestComing
                guard left != right else {
                    return lhs.author.name.localizedStandardCompare(rhs.author.name) == .orderedAscending
                }
                guard let left else { return false }
                guard let right else { return true }
                return left < right
            }
    }

    /// The authors with a work just out, an edition awaited out or a saga's
    /// volume just out, for the Authors shelf: the newest out first.
    var recentAuthors: [AuthorNews] {
        authorNews
            .filter(\.hasOut)
            .sorted { ($0.newestOut ?? "") > ($1.newestOut ?? "") }
    }

    /// The editions awaited in a format, the ones out first.
    func awaited(_ format: ReleaseFormat) -> [AwaitedEdition] { awaited[format] ?? [] }

    /// "Bientôt disponible": the editions awaited in both formats, translated
    /// and recorded together, in `soonOrder`.
    var awaitedSoon: [AwaitedEdition] {
        ReleaseFormat.allCases.flatMap(awaited).soonOrder
    }

    /// Whether the reader follows and awaits nothing in a format, as last
    /// session's snapshot or the server says.
    func holdsNothing(in format: ReleaseFormat) -> Bool {
        followed[format] == 0 && awaited(format).isEmpty
    }

    /// The format the award winners and the month's discoveries are shown in:
    /// the book's, unless the reader follows and awaits nothing read — a
    /// reader of recordings alone wants to know which winners they can hear.
    var awardsFormat: ReleaseFormat {
        holdsNothing(in: .book) && !holdsNothing(in: .audiobook) ? .audiobook : .book
    }
}

extension [AwaitedEdition] {
    /// The editions awaited still to come first, the soonest first and the
    /// undated last; then the ones out, the newest first; then the ones not
    /// announced yet, the latest awaited first.
    var soonOrder: [AwaitedEdition] {
        func rank(_ edition: AwaitedEdition) -> Int {
            switch edition.state {
            case .announced: 0
            case .available: 1
            default: 2
            }
        }
        func day(_ edition: AwaitedEdition) -> String? { edition.date.map(ReleaseDateText.lastDay) }
        return sorted { lhs, rhs in
            let (left, right) = (rank(lhs), rank(rhs))
            guard left == right else { return left < right }
            switch left {
            case 0:
                if day(lhs) != day(rhs) {
                    guard let leftDay = day(lhs) else { return false }
                    guard let rightDay = day(rhs) else { return true }
                    return leftDay < rightDay
                }
            case 1:
                if day(lhs) != day(rhs) {
                    guard let leftDay = day(lhs) else { return false }
                    guard let rightDay = day(rhs) else { return true }
                    return leftDay > rightDay
                }
            default:
                let (leftAt, rightAt) = (lhs.awaitedAt ?? .distantPast, rhs.awaitedAt ?? .distantPast)
                if leftAt != rightAt { return leftAt > rightAt }
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}

extension DiscoveryVolume {
    /// Still to come: announced for a day not reached, or for none yet.
    var isComing: Bool {
        volume.date.map { ReleaseDateText.isUpcoming($0) } ?? true
    }

    /// Under its cover: the day it comes or came out, or that it is announced.
    var caption: String {
        volume.date.map(ReleaseDateText.short) ?? String(localized: "Annoncé")
    }

    /// Drawn as the Books tab draws a book, the headphones on a recording's
    /// cover.
    var cover: Book {
        let series = saga.series
        return Book(
            id: "release-\(series.id)-\(volume.number)",
            title: volume.title,
            authors: series.author.map { [$0] } ?? [],
            format: series.isAudio ? .audiobook : .book,
            language: series.language,
            coverURL: volume.coverURL,
            status: .toRead
        )
    }

    /// What the look on the web knows, for its page: its title, author, cover
    /// and place in the saga.
    var book: Book {
        var book = cover
        book.isbn13 = volume.isbn13
        book.series = SeriesMembership(
            id: saga.series.seriesId,
            name: saga.series.name,
            volume: volume.number,
            kind: .main
        )
        return book
    }

    /// What the model is told: the volume as the watch found it.
    var seed: ReleaseSeed {
        let book = book
        return ReleaseSeed(
            title: book.title,
            authors: book.authors,
            format: book.format,
            language: book.language,
            series: book.series,
            isbn13: volume.isbn13,
            releasedOn: volume.date,
            coverURL: volume.coverURL
        )
    }

    /// What adding it to the pile sends: the page as shown, described or
    /// not, filed in its saga at its number, under the description's genre
    /// else the saga's.
    func draft(from shown: Book) -> BookDraft {
        var draft = BookDraft(title: shown.title, authors: shown.authors)
        draft.format = shown.format
        draft.genre = shown.genre ?? saga.series.genre
        draft.subgenres = shown.subgenres
        draft.synopsis = shown.synopsis
        draft.publisher = shown.publisher
        draft.firstPublishedIn = shown.firstPublishedIn
        draft.pageCount = shown.pageCount
        draft.isbn13 = shown.isbn13
        draft.language = saga.series.language
        draft.series = shown.series
        draft.coverURL = shown.coverURL
        draft.status = .toRead
        return draft
    }
}
