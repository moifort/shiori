import Apollo
import ApolloAPI
import Foundation

/// The Goodreads import, as the app talks to it. One place maps the generated
/// GraphQL types onto the domain model, so no screen touches a generated type.
enum GoodreadsAPI {
    /// A large export is read and written in one request: the function's
    /// ceiling plus a margin, as the Kindle import is given.
    private static let importTimeout: TimeInterval = 190

    /// What the file holds, against the library. Saves nothing.
    static func preview(csv: String) async throws -> GoodreadsPreview {
        do {
            let data = try await GraphQLHelpers.perform(
                GraphQLClient.shared.apollo,
                mutation: ShioriGraphQL.PreviewGoodreadsExportMutation(csv: csv),
                requestTimeout: importTimeout,
                changesLibrary: false
            )
            let preview = data.previewGoodreadsExport
            return GoodreadsPreview(
                rows: preview.rows.map { $0.fragments.goodreadsRowFields.asDomain },
                readCount: preview.shelves.read,
                readingCount: preview.shelves.reading,
                toReadCount: preview.shelves.toRead,
                droppedCount: preview.shelves.dropped,
                ratedCount: preview.rated,
                datedCount: preview.dated,
                reviewedCount: preview.reviewed
            )
        } catch let error as APIError {
            switch error.domainCode {
            case "GOODREADS_NOT_AN_EXPORT": throw GoodreadsFileError.notGoodreads
            case "GOODREADS_EMPTY_EXPORT": throw GoodreadsFileError.empty
            default: throw error
            }
        }
    }

    /// Writes the ticked rows from a second read of the same file.
    static func importExport(csv: String, choices: GoodreadsChoices) async throws -> GoodreadsImportOutcome {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ImportGoodreadsExportMutation(
                csv: csv,
                choices: ShioriGraphQL.GoodreadsChoicesInput(
                    keepDates: choices.keepDates,
                    keepRatings: choices.keepRatings,
                    keepReviews: choices.keepReviews,
                    keys: choices.keys.sorted(),
                    sameBooks: choices.sameBooks.sorted(),
                    toRead: .case(choices.toRead == .pile ? .pile : .wishlist)
                )
            ),
            requestTimeout: importTimeout
        )
        let outcome = data.importGoodreadsExport
        if outcome.wished > 0 {
            NotificationCenter.default.post(name: .shioriWishlistDidChange, object: nil)
        }
        return GoodreadsImportOutcome(
            imported: outcome.imported,
            completed: outcome.completed,
            wished: outcome.wished,
            pendingCovers: outcome.pendingCovers
        )
    }

    /// One pass of the cover search: how many were found, how many are left.
    static func seekCovers() async throws -> (found: Int, remaining: Int) {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SeekGoodreadsCoversMutation()
        )
        return (data.seekGoodreadsCovers.found, data.seekGoodreadsCovers.remaining)
    }

    /// The last import, nil when the reader never imported.
    static func lastImport() async throws -> GoodreadsImportSummary? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.GoodreadsImportQuery()
        )
        return data.goodreadsImport.map { record in
            GoodreadsImportSummary(
                importedAt: GraphQLHelpers.parseISO8601(record.importedAt) ?? .now,
                imported: record.imported,
                completed: record.completed,
                wished: record.wished,
                pendingCovers: record.pendingCovers,
                withoutCover: record.withoutCover
            )
        }
    }
}

private extension ShioriGraphQL.GoodreadsRowFields {
    var asDomain: GoodreadsRow {
        let shelf: GoodreadsShelf = switch self.shelf.value {
        case .read: .read
        case .currentlyReading: .currentlyReading
        case .toRead, nil: .toRead
        }
        let verdict: GoodreadsVerdict = switch self.verdict.value {
        case .held: .held
        case .uncertain: .uncertain
        case .new, nil: .new
        }
        return GoodreadsRow(
            key: key,
            title: title,
            authors: authors,
            seriesName: series?.name,
            volume: series?.volume,
            format: format.value?.asDomain ?? .book,
            media: media.compactMap { $0.value?.asDomain },
            language: language?.value?.asDomain,
            rating: rating,
            readOn: readOn.flatMap(GraphQLHelpers.parseISO8601),
            shelf: shelf,
            dropped: dropped,
            hasReview: hasReview,
            verdict: verdict,
            heldBookId: heldBookId,
            heldTitle: heldTitle,
            heldCoverURL: heldCoverUrl.flatMap(URL.init(string:)),
            coverURL: coverUrl.flatMap(URL.init(string:))
        )
    }
}
