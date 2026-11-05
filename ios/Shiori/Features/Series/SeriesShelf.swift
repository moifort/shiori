import Foundation

/// What the Library tab's series screens read off a followed saga: how far the
/// reader is, the next volume to read, the next one to come, what is missing.
extension FollowedSeries {
    /// Volumes of the cycle counted for "5 sur 7 lus": those out, owned or
    /// not; just the owned ones without a catalogue.
    var totalCount: Int {
        let counted = strip.filter {
            if case let .missing(_, _, _, forthcoming, _, _) = $0 { return !forthcoming }
            return true
        }
        return max(counted.count, ownedCount)
    }

    /// Volumes read, each once whatever the formats held.
    var readCount: Int {
        Set(strip.compactMap { item -> String? in
            guard case let .owned(book) = item, book.status == .read else { return nil }
            return book.series?.volume.map(String.init) ?? book.id
        }).count
    }

    /// Published volumes of the cycle the reader does not hold: what "À
    /// compléter" counts.
    var missingCount: Int {
        strip.filter {
            if case let .missing(_, _, _, forthcoming, _, _) = $0 { return !forthcoming }
            return false
        }.count
    }

    /// The volume to read next: the first held and not finished — the one
    /// open first — else the first out the reader lacks. Nil once the saga is
    /// read through.
    var nextVolume: NextVolume? {
        let owned = strip.compactMap { item -> Book? in
            if case let .owned(book) = item { return book }
            return nil
        }
        if let open = owned.first(where: { $0.status == .reading })
            ?? owned.first(where: { $0.status == .toRead }) {
            return .owned(open)
        }
        for item in strip {
            if case let .missing(_, number, title, forthcoming, _, coverURL) = item, !forthcoming {
                return .missing(number: number, title: title, coverURL: coverURL)
            }
        }
        return nil
    }

    /// The next volume announced, with its date when the release watch found
    /// one: what "Prochaines sorties" lists.
    var nextRelease: Release? {
        for item in strip {
            if case let .missing(_, number, title, true, date, coverURL) = item, let date {
                return Release(number: number, title: title, date: date, coverURL: coverURL)
            }
        }
        return nil
    }

    /// The cover the card is drawn with: the first volume held that has one,
    /// so a volume shelved later never changes the card the reader knows.
    var cardCoverURL: URL? {
        volumes.first(where: { $0.coverURL != nil })?.coverURL
    }

    /// The saga as the home's cards draw it.
    var progress: Dashboard.SeriesProgress {
        Dashboard.SeriesProgress(
            id: seriesId,
            name: name,
            isAudio: isAudio,
            language: language,
            readCount: readCount,
            totalCount: totalCount,
            rating: opinion?.rating,
            favorite: opinion?.favorite == true,
            coverURL: cardCoverURL
        )
    }

    /// Set aside by the reader: out of "À suivre", the releases and the home.
    var isSetAside: Bool { state == .unfollowed }

    /// The tag in the card's corner: the next volume's date, "Tome 15 · 12 déc." —
    /// the server's when the row carries it, so the card and "Prochaines
    /// sorties" agree.
    var releaseTag: String? {
        if let announced, let date = announced.date {
            return String(localized: "Tome \(announced.number) · \(ReleaseDateText.short(date))")
        }
        guard let release = nextRelease else { return nil }
        guard let number = release.number else { return ReleaseDateText.short(release.date) }
        return String(localized: "Tome \(number) · \(ReleaseDateText.short(release.date))")
    }

    enum NextVolume: Hashable {
        case owned(Book)
        case missing(number: Int?, title: String, coverURL: URL?)
    }

    struct Release: Hashable {
        let number: Int?
        let title: String
        let date: String
        let coverURL: URL?
    }
}

extension [FollowedSeries] {
    /// "À suivre": the sagas being read, the next volume of each.
    var upNext: [(series: FollowedSeries, volume: FollowedSeries.NextVolume)] {
        filter { $0.state == .inProgress }
            .compactMap { saga in saga.nextVolume.map { (saga, $0) } }
    }
}

extension ShelvesView {
    /// Whether a saga's next volume belongs to the view: the format a
    /// volume out the reader lacks takes is the saga's, its genre the saga's.
    func keeps(_ entry: (series: FollowedSeries, volume: FollowedSeries.NextVolume)) -> Bool {
        let format: BookFormat = switch entry.volume {
        case let .owned(book): book.format
        case .missing: entry.series.isAudio ? .audiobook : .book
        }
        let genre: BookGenre? = switch entry.volume {
        case let .owned(book): book.genre ?? entry.series.genre
        case .missing: entry.series.genre
        }
        return (self.format == nil || format == self.format) && (self.genre == nil || genre == self.genre)
    }
}

/// The filters of "Toutes les séries", each offered only when it holds a saga.
enum SeriesShelfFilter: String, CaseIterable, Identifiable, Sendable {
    case all, inProgress, incomplete, loved, notStarted, complete, notFollowed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: String(localized: "Toutes")
        case .inProgress: String(localized: "En cours")
        case .incomplete: String(localized: "À compléter")
        case .loved: String(localized: "Préférées")
        case .notStarted: String(localized: "À commencer")
        case .complete: String(localized: "Terminées")
        case .notFollowed: String(localized: "Non suivies")
        }
    }

    /// Whether the filter keeps the saga. A saga set aside is under
    /// "Non suivies" alone, the last pill.
    func keeps(_ series: FollowedSeries) -> Bool {
        if self == .notFollowed { return series.isSetAside }
        guard !series.isSetAside else { return false }
        switch self {
        case .all: return true
        case .inProgress: return series.state == .inProgress
        case .incomplete: return series.missingCount > 0
        case .loved: return series.opinion?.favorite == true || (series.opinion?.rating ?? 0) >= 4
        case .notStarted: return series.state == .notStarted
        case .complete: return series.state == .complete
        case .notFollowed: return true
        }
    }

    /// The filters that hold a saga, "Toutes" first and always.
    static func offered(for series: [FollowedSeries]) -> [SeriesShelfFilter] {
        allCases.filter { $0 == .all || series.contains(where: $0.keeps) }
    }
}
