import Foundation

/// The Amazon store an account was opened on, for Audible and Kindle alike. It
/// decides which domain the sign-in page and the library live on, so a
/// connection made on the wrong one finds an empty library — which is why the
/// reader picks it before signing in rather than after being told there is
/// nothing to import.
///
/// The raw value is the schema's own enum name rather than a lowercase slug:
/// `AudibleMarketplace` and `KindleMarketplace` share it, the mapping to either
/// generated type goes through it, and it keeps `IN` — a Swift keyword Apollo
/// has to escape — out of every switch in the app.
enum AmazonMarketplace: String, CaseIterable, Identifiable, Sendable {
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

    /// The store as Audible names it, for the Audible screens.
    var audibleLabel: String {
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

    /// The store as Amazon names it, for the Kindle screens and for a picker
    /// that serves both connections.
    var amazonLabel: String {
        switch self {
        case .fr: "amazon.fr"
        case .com: "amazon.com"
        case .coUk: "amazon.co.uk"
        case .de: "amazon.de"
        case .it: "amazon.it"
        case .es: "amazon.es"
        case .ca: "amazon.ca"
        case .comAu: "amazon.com.au"
        case .india: "amazon.in"
        case .coJp: "amazon.co.jp"
        }
    }

    /// The store the reader most likely buys from, guessed from the language
    /// the phone is set to. Only a default: the picker is right there, and a
    /// reader who bought abroad changes it in one tap.
    static var suggested: AmazonMarketplace {
        suggested(
            // The device's own first language, not the app's: the app speaks
            // French only, so its language would say French for everyone.
            language: Locale.preferredLanguages.first.map { Locale.Language(identifier: $0) },
            region: Locale.current.region?.identifier
        )
    }

    /// The language decides, and the region only settles a language several
    /// stores sell in: English, and French in Canada. A language no store
    /// sells in falls back on the region, then on audible.com.
    static func suggested(language: Locale.Language?, region: String?) -> AmazonMarketplace {
        let region = language?.region?.identifier ?? region
        switch language?.languageCode?.identifier {
        case "fr": return region == "CA" ? .ca : .fr
        case "de": return .de
        case "it": return .it
        case "es": return .es
        case "ja": return .coJp
        case "en":
            switch region {
            case "GB", "IE": return .coUk
            case "CA": return .ca
            case "AU", "NZ": return .comAu
            case "IN": return .india
            default: return .com
            }
        default:
            switch region {
            case "FR", "BE", "LU", "CH": return .fr
            case "GB", "IE": return .coUk
            case "DE", "AT": return .de
            case "IT": return .it
            case "ES": return .es
            case "CA": return .ca
            case "AU", "NZ": return .comAu
            case "IN": return .india
            case "JP": return .coJp
            default: return .com
            }
        }
    }
}

/// The reader's live link to Audible. Holds no credential: those never leave the
/// server.
struct AudibleAccount: Sendable {
    let marketplace: AmazonMarketplace
    let connectedAt: Date?
    let lastImportedAt: Date?
    /// Whether the nightly pass runs for this reader: it catalogues what was
    /// bought since the last one and follows the listening on books already
    /// imported, without asking.
    let autoSync: Bool
}

/// Everything the web view needs to run Amazon's sign-in, for an Audible or a
/// Kindle connection: the page, the cookies to plant first, the redirect that
/// carries the code back.
struct AmazonLogin: Identifiable, Sendable {
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

/// Where a library can be imported from. Each is a connection of its own —
/// its own Amazon sign-in, its own device, its own nightly pass — so a reader
/// links only what they use.
enum ImportSource: String, CaseIterable, Identifiable, Sendable {
    case audible
    case kindle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .audible: "Audible"
        case .kindle: "Kindle"
        }
    }

    var symbol: String {
        switch self {
        case .audible: "headphones"
        case .kindle: "ipad"
        }
    }

    /// What the settings row says under the name, since the two sources work
    /// nothing alike.
    var subtitle: String {
        switch self {
        case .audible: String(localized: "Connexion, import et synchronisation")
        case .kindle: String(localized: "Connexion, import et synchronisation")
        }
    }
}

/// What one pass over a connected library changed. Shown on the source card
/// right after the reader asks for it, so the button reports rather than just
/// stopping its spinner.
struct SyncOutcome: Sendable {
    let imported: Int
    let updated: Int

    var summary: String {
        switch (imported, updated) {
        case (0, 0):
            String(localized: "Rien de nouveau depuis la dernière fois.")
        case (let added, 0):
            String(localized: "\(added) livre(s) ajouté(s).")
        case (0, let moved):
            String(localized: "\(moved) livre(s) mis à jour.")
        case (let added, let moved):
            String(localized: "\(added) livre(s) ajouté(s), \(moved) mis à jour.")
        }
    }
}
