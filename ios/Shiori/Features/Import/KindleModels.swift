import Foundation

/// The reader's live link to their Kindle library. Holds no credential: those
/// never leave the server.
struct KindleAccount: Sendable {
    let marketplace: AmazonMarketplace
    let connectedAt: Date?
    let lastImportedAt: Date?
    /// Whether the nightly pass runs: it catalogues what was acquired since the
    /// last one and moves to read what Kindle newly marks read, without asking.
    let autoSync: Bool
    /// When the nightly pass last failed — Amazon refusing the device, most
    /// often — nil once one works again. The screen offers to connect again.
    let lastSyncFailedAt: Date?
}

/// One Kindle book of the library, as it would be catalogued. A proposal:
/// nothing is saved until the reader ticks it and confirms.
struct ImportableKindleBook: Identifiable, Sendable {
    var id: String { asin }

    let asin: String
    let title: String
    let authors: [String]
    let coverURL: URL?
    let seriesName: String?
    let volume: Int?
    let status: ReadingStatus
    /// A book with the same title and author is already catalogued, whatever
    /// its edition.
    let alreadyInLibrary: Bool

    var authorLine: String {
        authors.isEmpty ? String(localized: "Auteur inconnu") : authors.joined(separator: ", ")
    }

    /// "Powerless 3" — the saga Amazon put in the title, on one line under the
    /// authors.
    var detailLine: String {
        guard let seriesName else { return "" }
        return volume.map { "\(seriesName) \($0)" } ?? seriesName
    }

    /// A stand-in book, only so the row can draw the shared cover component —
    /// including its typographic placeholder when Amazon has no image.
    var asCoverSubject: Book {
        Book(id: asin, title: title, authors: authors, coverURL: coverURL, status: status)
    }
}

extension KindleAccount {
    /// A library linked a few weeks ago, synced last night, for previews.
    static let preview = KindleAccount(
        marketplace: .fr,
        connectedAt: Date().addingTimeInterval(-86400 * 12),
        lastImportedAt: Date().addingTimeInterval(-86400),
        autoSync: true,
        lastSyncFailedAt: nil
    )

    /// The same, after a night Amazon refused the device.
    static let refusedPreview = KindleAccount(
        marketplace: .fr,
        connectedAt: Date().addingTimeInterval(-86400 * 90),
        lastImportedAt: Date().addingTimeInterval(-86400 * 3),
        autoSync: true,
        lastSyncFailedAt: Date()
    )
}

extension ImportableKindleBook {
    /// A short Kindle library, for previews: a saga half read, a book already
    /// on the shelf, a standalone title.
    static let previews: [ImportableKindleBook] = [
        ImportableKindleBook(
            asin: "B0G26NZ911",
            title: "Fearless",
            authors: ["Lauren Roberts"],
            coverURL: nil,
            seriesName: "Powerless",
            volume: 3,
            status: .toRead,
            alreadyInLibrary: false
        ),
        ImportableKindleBook(
            asin: "B0FBM5PXX6",
            title: "Reckless",
            authors: ["Lauren Roberts"],
            coverURL: nil,
            seriesName: "Powerless",
            volume: 2,
            status: .read,
            alreadyInLibrary: false
        ),
        ImportableKindleBook(
            asin: "B0GGX6LNFM",
            title: "Taming 7",
            authors: ["Chloe Walsh"],
            coverURL: nil,
            seriesName: "Boys of Tommen",
            volume: 5,
            status: .read,
            alreadyInLibrary: true
        ),
        ImportableKindleBook(
            asin: "B0CXYZ1234",
            title: "La Femme de ménage",
            authors: ["Freida McFadden"],
            coverURL: nil,
            seriesName: nil,
            volume: nil,
            status: .read,
            alreadyInLibrary: false
        ),
    ]
}
