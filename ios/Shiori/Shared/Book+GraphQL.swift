import Foundation

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
        case .dropped: .dropped
        }
    }
}

extension ShioriGraphQL.BookFormat {
    var asDomain: BookFormat {
        switch self {
        case .book: .book
        case .ebook: .ebook
        case .audiobook: .audiobook
        case .bandeDessinee: .bandeDessinee
        case .comic: .comic
        case .manga: .manga
        }
    }
}

extension ShioriGraphQL.Genre {
    var asDomain: BookGenre {
        switch self {
        case .fantasy: .fantasy
        case .scienceFiction: .scienceFiction
        case .horror: .horror
        case .crime: .crime
        case .thriller: .thriller
        case .romance: .romance
        case .historicalFiction: .historicalFiction
        case .adventure: .adventure
        case .literaryFiction: .literaryFiction
        case .humor: .humor
        case .poetry: .poetry
        case .drama: .drama
        case .biography: .biography
        case .history: .history
        case .essay: .essay
        case .science: .science
        case .selfHelp: .selfHelp
        case .business: .business
        case .art: .art
        case .cooking: .cooking
        case .travel: .travel
        case .other: .other
        }
    }
}

extension ShioriGraphQL.BookLanguage {
    var asDomain: BookLanguage {
        switch self {
        case .fr: .fr
        case .en: .en
        case .es: .es
        case .de: .de
        case .it: .it
        case .pt: .pt
        case .nl: .nl
        case .sv: .sv
        case .pl: .pl
        case .ru: .ru
        case .uk: .uk
        case .tr: .tr
        case .ar: .ar
        case .ja: .ja
        case .zh: .zh
        case .ko: .ko
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
        case .notStarted: .notStarted
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

extension GraphQLEnum where T == ShioriGraphQL.BookFormat {
    /// An unrecognized format reads as a plain book, the format of nearly every
    /// title and the one that draws no label on a row.
    var asDomain: BookFormat {
        if case let .case(value) = self { return value.asDomain }
        return .book
    }
}

extension GraphQLEnum where T == ShioriGraphQL.Genre {
    /// An unrecognized genre reads as "other": it is the one value that claims
    /// nothing about the book.
    var asDomain: BookGenre {
        if case let .case(value) = self { return value.asDomain }
        return .other
    }
}

extension GraphQLEnum where T == ShioriGraphQL.BookLanguage {
    /// An unrecognized language reads as none at all. It is a language this
    /// client cannot name or draw a flag for, and guessing would shelve the book
    /// under a language nobody established.
    var asDomain: BookLanguage? {
        if case let .case(value) = self { return value.asDomain }
        return nil
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
            format: format.asDomain,
            genre: genre?.asDomain,
            subgenres: subgenres,
            language: language?.asDomain,
            series: series?.asMembership,
            coverURL: coverUrl.flatMap(URL.init(string:)),
            status: status.asDomain,
            rating: rating,
            seriesRating: seriesRating,
            favorite: favorite,
            shelvedAt: GraphQLHelpers.parseISO8601(shelvedAt)
        )
    }
}

extension ShioriGraphQL.BookDetail {
    var asBook: Book {
        Book(
            id: id,
            title: title,
            authors: authors,
            format: format.asDomain,
            publisher: publisher,
            firstPublishedIn: firstPublishedIn,
            synopsis: synopsis,
            genre: genre?.asDomain,
            subgenres: subgenres,
            pageCount: pageCount,
            durationMinutes: durationMinutes,
            narrators: narrators,
            isbn13: isbn13,
            language: language?.asDomain,
            series: series?.asMembership,
            coverURL: coverUrl.flatMap(URL.init(string:)),
            status: status.asDomain,
            rating: rating,
            seriesRating: seriesRating,
            favorite: favorite,
            note: note,
            hidden: hidden,
            addedAt: GraphQLHelpers.parseISO8601(addedAt),
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

extension ShioriGraphQL.SeriesOpinionFields {
    var asOpinion: SeriesOpinion {
        SeriesOpinion(seriesId: seriesId, rating: rating, favorite: favorite, volumeCount: volumeCount)
    }
}
