import Foundation

/// Where a row sits in a favourites view, as the server ranks it: the hearts
/// first, then five stars down to one. A saga's full marks lent to a volume
/// left unrated are drawn as the saga's heart, so they head the list with the
/// hearts rather than under five stars.
enum LovedRank: Hashable {
    case hearts
    case stars(Int)

    /// Nil for what the reader has not judged, which the favourites leave out.
    init?(favorite: Bool, rating: Int?, lentRating: Int? = nil) {
        if favorite || (rating == nil && lentRating == 5) {
            self = .hearts
        } else if let stars = rating ?? lentRating {
            self = .stars(stars)
        } else {
            return nil
        }
    }

    /// Lower comes first.
    var order: Int {
        switch self {
        case .hearts: 0
        case .stars(let count): 6 - count
        }
    }

    var title: String {
        switch self {
        case .hearts: String(localized: "Coups de cœur")
        case .stars(1): String(localized: "1 étoile")
        case .stars(let count): String(localized: "\(count) étoiles")
        }
    }
}

/// One heading of a list and the rows under it: a month in the lists by date,
/// a rank in the favourites.
struct ListSection<Row>: Identifiable {
    let id: String
    let title: String
    var rows: [Row]

    /// The rows cut into months, newest first, on the date given.
    static func byMonth(_ rows: [Row], on date: (Row) -> Date?) -> [ListSection<Row>] {
        MonthSection.cut(rows, on: date).map { ListSection(id: $0.id, title: $0.title, rows: $0.rows) }
    }

    /// The rows cut wherever their rank changes, in the order the server ranked
    /// them. A row with no rank — only a stale snapshot can hold one — goes
    /// under a heading of its own rather than among the judged.
    static func byRank(_ rows: [Row], rank: (Row) -> LovedRank?) -> [ListSection<Row>] {
        // Ids counted per rank, as months are, so a refresh keeps them stable.
        var sections: [(rank: LovedRank?, section: ListSection<Row>)] = []
        var runs: [LovedRank?: Int] = [:]
        for row in rows {
            let current = rank(row)
            if let last = sections.last, last.rank == current {
                sections[sections.count - 1].section.rows.append(row)
            } else {
                let run = runs[current, default: 0]
                runs[current] = run + 1
                let id = "\(current.map { "\($0.order)" } ?? "none")#\(run)"
                let title = current?.title ?? String(localized: "Sans note")
                sections.append((current, ListSection(id: id, title: title, rows: [row])))
            }
        }
        return sections.map(\.section)
    }
}

extension Book {
    /// Its rank among the favourites: its own heart or stars, else its saga's —
    /// lent only once it is read, as the row draws them.
    var lovedRank: LovedRank? {
        LovedRank(favorite: favorite, rating: rating, lentRating: status == .read ? seriesRating : nil)
    }
}

extension FollowedSeries {
    var lovedRank: LovedRank? {
        LovedRank(favorite: opinion?.favorite == true, rating: opinion?.rating)
    }
}

extension FriendSaga {
    var lovedRank: LovedRank? {
        LovedRank(favorite: favorite, rating: rating)
    }
}
