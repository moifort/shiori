import Apollo
import ApolloAPI
import Foundation

/// The Audible import, as the app talks to it. One place maps the generated
/// GraphQL types onto the domain model, so no screen ever touches a generated
/// type — the same rule `LibraryAPI` follows.
enum ImportAPI {
    /// An import is one request that reads a whole Audible library and writes a
    /// whole shelf, so it legitimately keeps the server silent for longer than
    /// the session's 60 s idle limit. Sized like a scan: the function's own
    /// ceiling plus a margin, so a request that runs over receives the server's
    /// 504 rather than both sides giving up at the same instant.
    private static let importTimeout: TimeInterval = 190

    static func account() async throws -> AudibleAccount? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.AudibleAccountQuery()
        )
        return data.audibleAccount?.fragments.audibleAccountSummary.asDomain
    }

    static func startSignIn(on marketplace: AudibleMarketplace) async throws -> AudibleLogin {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.StartAudibleLoginMutation(
                marketplace: GraphQLEnum(rawValue: marketplace.rawValue)
            )
        )
        let login = data.startAudibleLogin
        return AudibleLogin(
            url: login.url,
            redirectURL: login.redirectUrl,
            cookies: login.cookies.map {
                AudibleLogin.Cookie(name: $0.name, value: $0.value, domain: $0.domain)
            }
        )
    }

    /// Trades the authorization code the web view caught for the connection.
    /// Throws `APIError.domain(code: "AUDIBLE_LOGIN_EXPIRED")` past the server's
    /// thirty-minute window, which the screen turns into "start again" rather
    /// than a bare error.
    static func completeSignIn(authorizationCode: String) async throws -> AudibleAccount {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.CompleteAudibleLoginMutation(
                authorizationCode: authorizationCode
            )
        )
        return data.completeAudibleLogin.fragments.audibleAccountSummary.asDomain
    }

    /// The whole Audible library as books the reader could catalogue. Saves
    /// nothing and costs no scan credit. Throws
    /// `APIError.domain(code: "AUDIBLE_NOT_CONNECTED")` with no account linked.
    static func library() async throws -> [ImportableBook] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.AudibleLibraryQuery()
        )
        return data.audibleLibrary.map { item in
            ImportableBook(
                asin: item.asin,
                title: item.title,
                authors: item.authors,
                narrators: item.narrators,
                durationMinutes: item.durationMinutes,
                coverURL: item.coverUrl.flatMap(URL.init(string:)),
                seriesName: item.seriesName,
                volume: item.volume,
                status: item.status.asDomain,
                finishedAt: item.finishedAt.flatMap(GraphQLHelpers.parseISO8601),
                alreadyInLibrary: item.alreadyInLibrary
            )
        }
    }

    /// Catalogues the ticked titles and returns the books created. The server
    /// re-reads the library rather than trusting these identifiers, and skips a
    /// title already catalogued — so a retry after a timeout creates no
    /// duplicates.
    static func importBooks(asins: [String]) async throws -> [Book] {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ImportAudibleBooksMutation(asins: asins),
            requestTimeout: importTimeout
        )
        return data.importAudibleBooks.map { $0.fragments.bookSummary.asBook }
    }

    /// Turns the nightly sync on or off. Answers with the stored account, so the
    /// screen draws what was kept rather than what it flipped.
    static func setAutoSync(_ enabled: Bool) async throws -> AudibleAccount {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SetAudibleAutoSyncMutation(enabled: enabled)
        )
        return data.setAudibleAutoSync.fragments.audibleAccountSummary.asDomain
    }

    /// Runs the nightly pass now, whatever the switch says, and reports what it
    /// changed alongside the account it left behind — so the card redraws its
    /// date and its counts in one round trip.
    ///
    /// Reads the whole Audible library and can write a whole shelf, so it is
    /// given the import's timeout rather than the session's own.
    static func syncNow() async throws -> (outcome: AudibleSyncOutcome, account: AudibleAccount) {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SyncAudibleNowMutation(),
            requestTimeout: importTimeout
        )
        let sync = data.syncAudibleNow
        return (
            AudibleSyncOutcome(imported: sync.imported, updated: sync.updated),
            sync.account.fragments.audibleAccountSummary.asDomain
        )
    }

    /// Forgets our copy of the credentials. The device stays registered on the
    /// Amazon side until the reader removes it there, which the screen says.
    static func disconnect() async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DisconnectAudibleMutation()
        )
    }

    // MARK: - Kindle

    /// Reads an Amazon data export into books to tick. Saves nothing, calls no
    /// model, and spends no scan: this reads a file.
    static func readKindleExport(csv: String) async throws -> [KindleBook] {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ReadKindleExportMutation(csv: csv)
        )
        return data.readKindleExport.map {
            KindleBook(
                key: $0.key,
                title: $0.title,
                authors: $0.authors,
                alreadyInLibrary: $0.alreadyInLibrary
            )
        }
    }

    /// Catalogues the ticked titles. The file goes back with the keys: the
    /// server reads it again rather than trusting records the app composed, so
    /// every stored field comes from the export.
    static func importKindleBooks(csv: String, keys: [String]) async throws -> [Book] {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ImportKindleBooksMutation(csv: csv, keys: keys),
            requestTimeout: importTimeout
        )
        return data.importKindleBooks.map { $0.fragments.bookDetail.asBook }
    }
}

extension ShioriGraphQL.AudibleAccountSummary {
    /// A marketplace this build does not know reads as `.com`: the account is
    /// connected either way, and the label is the only thing that suffers.
    var asDomain: AudibleAccount {
        AudibleAccount(
            marketplace: AudibleMarketplace(rawValue: marketplace.rawValue) ?? .com,
            connectedAt: GraphQLHelpers.parseISO8601(connectedAt),
            lastImportedAt: lastImportedAt.flatMap(GraphQLHelpers.parseISO8601),
            autoSync: autoSync
        )
    }
}
