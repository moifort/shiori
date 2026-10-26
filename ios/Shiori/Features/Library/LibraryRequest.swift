import Foundation

/// The two ways the Library tab looks at the shelf, switched from the toolbar
/// as Vinarium switches its wine list: everything, or the favourites — every
/// book judged, the hearts first and then five stars down to one.
enum LibraryMode: String, CaseIterable, Identifiable {
    case all, favorites
    var id: String { rawValue }

    /// The views the Series tab shares: sagas are hearted as books are.
    static let seriesViews: [LibraryMode] = [.all, .favorites]

    var label: String {
        switch self {
        case .all: String(localized: "Tout")
        case .favorites: String(localized: "Favoris")
        }
    }

    var icon: String {
        switch self {
        case .all: "clock"
        case .favorites: "heart.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .all: String(localized: "Par date")
        case .favorites: String(localized: "Cœurs, puis étoiles")
        }
    }
}

/// What the Library tab's filter keeps: one reading status, or the books the
/// reader hearted. Either way the list stays in its own order.
enum LibraryFilter: Hashable {
    case status(ReadingStatus)
    case favorites

    var status: ReadingStatus? {
        if case let .status(status) = self { status } else { nil }
    }

    var symbol: String {
        switch self {
        case let .status(status): status.symbol
        case .favorites: "heart.fill"
        }
    }

    var title: String {
        switch self {
        case let .status(status): status.shelfTitle
        case .favorites: String(localized: "Favoris")
        }
    }

    /// The name of the view's snapshot on disk.
    fileprivate var cacheKey: String {
        switch self {
        case let .status(status): status.rawValue
        case .favorites: "favorites"
        }
    }

    func keeps(_ book: Book) -> Bool {
        switch self {
        case let .status(status): book.status == status
        case .favorites: book.favorite
        }
    }
}

/// A view of the Library tab another screen asks it to open on: the list by
/// date unless a mode says otherwise, narrowed by the filter.
struct LibraryRequest: Equatable {
    var mode: LibraryMode = .all
    var filter: LibraryFilter?
    /// A book just added, scrolled to wherever its date shelves it in the
    /// list by date, every book shown.
    var focus: String?
}
