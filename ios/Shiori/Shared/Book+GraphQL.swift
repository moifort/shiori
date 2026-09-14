import Foundation
import ShioriGraphQL

/// Mapping from the generated GraphQL types to the domain model.
///
/// Every conversion lives here rather than in the API enums, so a schema change
/// lands in one file. Unknown enum cases are mapped to the safest neighbour
/// rather than crashing: the schema is not versioned, so a client can legitimately
/// meet a value added after it shipped.
extension ShioriGraphQL.ReadingStatus {
    var asDomain: ReadingStatus {
        switch self {
        case .toRead: .toRead
        case .reading: .reading
        case .read: .read
        }
    }
}

extension ShioriGraphQL.VolumeKind {
    var asDomain: VolumeKind {
        switch self {
        case .main: .main
        case .prequel: .prequel
        case .spinOff: .spinOff
        case .novella: .novella
        case .companion: .companion
        }
    }
}

extension ShioriGraphQL.SeriesState {
    var asDomain: SeriesState {
        switch self {
        case .inProgress: .inProgress
        case .complete: .complete
        }
    }
}

extension GraphQLEnum where T == ShioriGraphQL.ReadingStatus {
    /// An unrecognized status reads as "to read": it is the only state that is
    /// true of every book, so it cannot assert something false about this one.
    var asDomain: ReadingStatus {
        if case let .case(value) = self { return value.asDomain }
        return .toRead
    }
}

extension GraphQLEnum where T == ShioriGraphQL.VolumeKind {
    /// An unrecognized kind lands in the related works rather than the spine:
    /// showing an unknown volume as part of the main story would misnumber it.
    var asDomain: VolumeKind {
        if case let .case(value) = self { return value.asDomain }
        return .companion
    }
}

extension GraphQLEnum where T == ShioriGraphQL.SeriesState {
    var asDomain: SeriesState {
        if case let .case(value) = self { return value.asDomain }
        return .inProgress
    }
}

extension ShioriGraphQL.BookSummary {
    var asBook: Book {
        Book(
            id: id,
            title: title,
            authors: authors,
            series: series?.asMembership,
            coverURL: coverUrl.flatMap(URL.init(string:)),
            status: status.asDomain,
            rating: rating
        )
    }
}

extension ShioriGraphQL.BookDetail {
    var asBook: Book {
        Book(
            id: id,
            title: title,
            authors: authors,
            publisher: publisher,
            firstPublishedIn: firstPublishedIn,
            synopsis: synopsis,
            genres: genres,
            pageCount: pageCount,
            isbn13: isbn13,
            series: series?.asMembership,
            coverURL: coverUrl.flatMap(URL.init(string:)),
            status: status.asDomain,
            rating: rating,
            note: note,
            hidden: hidden,
            addedAt: addedAt.flatMap(GraphQLHelpers.parseISO8601),
            startedAt: startedAt.flatMap(GraphQLHelpers.parseISO8601),
            finishedAt: finishedAt.flatMap(GraphQLHelpers.parseISO8601)
        )
    }
}

extension ShioriGraphQL.BookSummary.Series {
    var asMembership: SeriesMembership {
        SeriesMembership(id: id, name: name, volume: volume, kind: kind.asDomain)
    }
}

extension ShioriGraphQL.BookDetail.Series {
    var asMembership: SeriesMembership {
        SeriesMembership(id: id, name: name, volume: volume, kind: kind.asDomain)
    }
}

extension ShioriGraphQL.VolumeEntry {
    var asVolume: Volume {
        Volume(number: number, title: title, publishedIn: publishedIn, kind: kind.asDomain)
    }
}
