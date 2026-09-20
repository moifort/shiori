import Foundation

/// The Amazon store an Audible account was opened on. It decides which domain
/// the sign-in page and the API live on, so a connection made on the wrong one
/// finds an empty library — which is why the reader picks it before signing in
/// rather than after being told there is nothing to import.
///
/// The raw value is the schema's own enum name rather than a lowercase slug:
/// the mapping to the generated type goes through it, which keeps `IN` — a Swift
/// keyword Apollo has to escape — out of every switch in the app.
enum AudibleMarketplace: String, CaseIterable, Identifiable, Sendable {
    case fr = "FR"
    case com = "COM"
    case coUk = "CO_UK"
    case de = "DE"
    case it = "IT"
    case es = "ES"
    case ca = "CA"
    case comAu = "COM_AU"
    case india = "IN"
    case coJp = "CO_JP"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fr: "audible.fr"
        case .com: "audible.com"
        case .coUk: "audible.co.uk"
        case .de: "audible.de"
        case .it: "audible.it"
        case .es: "audible.es"
        case .ca: "audible.ca"
        case .comAu: "audible.com.au"
        case .india: "audible.in"
        case .coJp: "audible.co.jp"
        }
    }

    /// The store the reader most likely buys from, guessed from the device
    /// region. Only a default: the picker is right there, and a reader who
    /// bought abroad changes it in one tap.
    static var suggested: AudibleMarketplace {
        switch Locale.current.region?.identifier {
        case "FR", "BE", "LU", "CH": .fr
        case "GB", "IE": .coUk
        case "DE", "AT": .de
        case "IT": .it
        case "ES": .es
        case "CA": .ca
        case "AU", "NZ": .comAu
        case "IN": .india
        case "JP": .coJp
        default: .com
        }
    }
}

/// The reader's live link to Audible. Holds no credential: those never leave the
/// server.
struct AudibleAccount: Sendable {
    let marketplace: AudibleMarketplace
    let connectedAt: Date?
    let lastImportedAt: Date?
    /// Whether the nightly pass runs for this reader: it catalogues what was
    /// bought since the last one and follows the listening on books already
    /// imported, without asking.
    let autoSync: Bool
}

/// Everything the web view needs to run Amazon's sign-in.
struct AudibleLogin: Identifiable, Sendable {
    /// The sign-in URL doubles as the identity of this attempt: a new sign-in
    /// carries a new PKCE challenge, which is what has to re-present the sheet.
    var id: String { url }

    let url: String
    let redirectURL: String
    let cookies: [Cookie]

    struct Cookie: Sendable {
        let name: String
        let value: String
        let domain: String
    }
}

/// One audiobook of the Audible library, as it would be catalogued. A proposal:
/// nothing is saved until the reader ticks it and confirms.
struct ImportableBook: Identifiable, Sendable {
    var id: String { asin }

    let asin: String
    let title: String
    let authors: [String]
    let narrators: [String]
    let durationMinutes: Int?
    let coverURL: URL?
    let seriesName: String?
    let volume: Int?
    let status: ReadingStatus
    let finishedAt: Date?
    /// A book with the same title and author is already catalogued — whether it
    /// was imported before or scanned from the printed edition.
    let alreadyInLibrary: Bool

    var authorLine: String {
        authors.isEmpty ? String(localized: "Auteur inconnu") : authors.joined(separator: ", ")
    }

    /// "Tome 3 · 29 h 30" — what tells two recordings of the same work apart, on
    /// one line under the authors.
    var detailLine: String {
        var parts: [String] = []
        if let seriesName {
            parts.append(volume.map { "\(seriesName) \($0)" } ?? seriesName)
        }
        if let duration = durationLabel { parts.append(duration) }
        if !narrators.isEmpty { parts.append(narrators.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }

    private var durationLabel: String? {
        guard let durationMinutes, durationMinutes > 0 else { return nil }
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes))" : "\(minutes) min"
    }

    /// A stand-in book, only so the row can draw the shared cover component —
    /// including its typographic placeholder when Audible has no image.
    var asCoverSubject: Book {
        Book(id: asin, title: title, authors: authors, coverURL: coverURL, status: status)
    }
}
