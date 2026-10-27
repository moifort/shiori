import Foundation

/// Everything a narrator's page asks of the server, as closures: `.live` goes
/// through `NarratorsAPI`, a preview builds the one it needs.
struct NarratorsClient: Sendable {
    /// A narrator's page; nil when the reader holds no recording of theirs,
    /// unless `offered` names them.
    var page: @Sendable (_ key: String, _ offered: String?) async throws -> NarratorPage?
    /// The page once the AI has described a narrator nobody had.
    var catalogue: @Sendable (_ key: String, _ offered: String?) async throws -> NarratorPage?
    /// Hearts the narrator or takes the heart back; answers what is now true.
    var setFavorite: @Sendable (_ key: String, Bool) async throws -> Bool
    /// What the world knows of the narrator, corrected for every reader;
    /// answers the page as it now reads.
    var correct: @Sendable (_ key: String, PersonCorrection) async throws -> NarratorPage? = { _, _ in nil }
    /// The faces the reader may give the narrator, the one drawn now first.
    var portraitChoices: @Sendable (_ key: String) async throws -> [PortraitChoice] = { _ in [] }
    /// One page of the Library's narrators list after the given cursor, in that order.
    var list: @Sendable (_ limit: Int, _ after: String?, AuthorListOrder)
        async throws -> CursorPage<FollowedNarrator> = { _, _, _ in CursorPage(items: [], hasMore: false, endCursor: nil) }
}

extension NarratorsClient {
    static let live = NarratorsClient(
        page: { try await NarratorsAPI.page(key: $0, offered: $1) },
        catalogue: { try await NarratorsAPI.page(key: $0, offered: $1, waitForCatalogue: true) },
        setFavorite: { try await NarratorsAPI.setFavorite(key: $0, favorite: $1) },
        correct: { try await NarratorsAPI.correct(key: $0, correction: $1) },
        portraitChoices: { try await NarratorsAPI.portraitChoices(key: $0) },
        list: { try await NarratorsAPI.myNarratorsPage(limit: $0, after: $1, order: $2) }
    )
}

extension NarratorPage {
    static let preview = NarratorPage(
        key: "bernard-gabay",
        name: "Bernard Gabay",
        portraitURL: nil,
        favorite: false,
        bookCount: 4,
        readCount: 2,
        seriesCount: 1,
        averageRating: 4.5,
        sagas: [],
        books: [.preview],
        nationality: "Français",
        birthYear: 1960,
        biography: "Comédien français, voix française de Robert Downey Jr. et de Johnny Depp, il prête aussi sa voix à de nombreux livres audio."
    )
}

extension NarratorsClient {
    /// Answers from the fixtures and accepts every write.
    static let preview = NarratorsClient(
        page: { _, _ in .preview },
        catalogue: { _, _ in .preview },
        setFavorite: { _, favorite in favorite },
        correct: { _, _ in .preview },
        portraitChoices: { _ in PortraitChoice.previews },
        list: { limit, after, _ in
            CursorPage(FollowedNarrator.previews, limit: limit, after: after, cursor: \.id)
        }
    )
}
