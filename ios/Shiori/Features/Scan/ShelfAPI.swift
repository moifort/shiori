import Foundation
import UIKit

/// One book found in a shelf photo, as printed — nothing looked up yet. The
/// title and authors are the reader's to correct on the checklist.
struct DetectedBook: Identifiable, Hashable {
    /// Its place in reading order: stable for the life of the checklist.
    let id: Int
    var title: String?
    var authors: [String]
    let publisher: String?
    let language: BookLanguage?
    let format: BookFormat?
    /// Digital for a cover shown on a screen; empty when the photo did not say.
    var media: [BookMedium] = []
    let seriesName: String?
    let volume: Int?
    /// Where it sits, as fractions of the photo that was sent.
    let box: CGRect
    /// The reader already has this story: it comes unticked.
    let owned: Bool

    var byline: String? {
        authors.isEmpty ? nil : authors.joined(separator: ", ")
    }

    var seriesLabel: String? {
        seriesName.map { name in volume.map { "\(name) · Tome \($0)" } ?? name }
    }

    /// Whether the checklist can tick it: an unreadable spine needs a title first.
    var isNamed: Bool {
        title?.isEmpty == false
    }
}

enum ShelfAPI {
    /// A shelf photo is read in one call without web search, but a large
    /// photo still takes a while: the same ceiling as a scan.
    private static let requestTimeout: TimeInterval = 190

    /// Throws `APIError.domain(code: "PREMIUM_REQUIRED")` for a free account
    /// and `"QUOTA_EXHAUSTED"` once nothing is left.
    static func detect(jpeg: Data) async throws -> [DetectedBook] {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DetectBooksMutation(imageBase64: jpeg.base64EncodedString()),
            requestTimeout: requestTimeout,
            // A proposal: nothing reaches the library before `addBook`.
            changesLibrary: false
        )
        return data.detectBooks.enumerated().map { index, book in
            DetectedBook(
                id: index,
                title: book.title,
                authors: book.authors,
                publisher: book.publisher,
                language: book.language?.asDomain,
                format: book.format?.asDomain,
                media: book.media.asDomain,
                seriesName: book.seriesName,
                volume: book.volume,
                box: CGRect(x: book.box.x, y: book.box.y, width: book.box.width, height: book.box.height),
                owned: book.owned
            )
        }
    }

    /// Spends one scan. The answer is saved with `BookAPI.add`, as a scan's is.
    static func describe(_ book: DetectedBook) async throws -> ScannedBook {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DescribeDetectedBookMutation(
                book: ShioriGraphQL.DetectedBookInput(
                    authors: book.authors,
                    format: GraphQLHelpers.graphQLNullable(book.format.map(LibraryAPI.graphQLFormat)),
                    language: GraphQLHelpers.graphQLNullable(book.language.map(LibraryAPI.graphQLLanguage)),
                    media: book.media.isEmpty ? .none : .some(LibraryAPI.graphQLMedia(book.media)),
                    publisher: GraphQLHelpers.graphQLNullable(book.publisher),
                    title: book.title ?? ""
                )
            ),
            requestTimeout: requestTimeout,
            // A proposal: the view model saves it with `addBook` right after.
            changesLibrary: false
        )
        return ScannedBook(fields: data.describeDetectedBook.fragments.scannedRecord)
    }
}

extension UIImage {
    /// The part of the photo inside a box given as fractions of it. Drawn
    /// through a renderer so the photo's orientation is applied first — the
    /// box was measured on the upright image the server saw.
    func crop(to box: CGRect) -> UIImage? {
        let rect = CGRect(
            x: box.minX * size.width,
            y: box.minY * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        ).integral
        guard rect.width > 0, rect.height > 0 else { return nil }
        return UIGraphicsImageRenderer(size: rect.size, format: .pixelExact).image { _ in
            draw(at: CGPoint(x: -rect.minX, y: -rect.minY))
        }
    }
}
