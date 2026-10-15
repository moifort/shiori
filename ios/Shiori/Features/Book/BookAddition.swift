import Foundation

/// "Look the book up, then add it": the one way a screen offering a book it
/// does not hold — a saga's volume, an author's work, an award winner, an
/// announced volume, a suggestion — puts it on the shelf.
enum BookAddition {
    /// What the book is looked up by, for its cover and its details, before it
    /// is added.
    enum LookUp: Sendable {
        /// A free title, "Title — Author".
        case title(String)
        /// A saga's volume, looked up in the edition it is filed under.
        case volume(
            title: String,
            author: String,
            membership: SeriesMembership,
            format: BookFormat,
            media: [BookMedium],
            language: BookLanguage?
        )
    }

    /// Adds `draft`, looked up first when `lookUp` says how. What the caller
    /// decided — the format, the media, the saga, the status, and the
    /// language when it said one — is kept whatever the lookup answered; its
    /// title and authors too when the lookup found none. A lookup that fails
    /// or recognises nothing adds the draft as it is.
    static func add(
        _ draft: BookDraft,
        lookingUp lookUp: LookUp? = nil,
        source: AnalyticsEvent.BookSource
    ) async throws -> Book {
        var draft = draft
        if let lookUp, let found = try? await find(lookUp), found.recognized {
            draft = draft.completed(by: found.asDraft)
        }
        let added = try await BookAPI.add(draft)
        track(.bookAdded(source: source))
        return added
    }

    private static func find(_ lookUp: LookUp) async throws -> ScannedBook {
        switch lookUp {
        case let .title(title):
            try await ScanAPI.lookUp(title: title)
        case let .volume(title, author, membership, format, media, language):
            try await ScanAPI.lookUp(
                volume: title,
                author: author,
                membership: membership,
                format: format,
                media: media,
                language: language
            )
        }
    }
}

extension BookDraft {
    /// The lookup's record, with what the caller decided laid over it.
    func completed(by found: BookDraft) -> BookDraft {
        var merged = found
        if merged.title.isEmpty { merged.title = title }
        if merged.authors.isEmpty { merged.authors = authors }
        merged.format = format
        merged.media = media
        merged.series = series ?? found.series
        merged.language = language ?? found.language
        merged.status = status
        return merged
    }
}
