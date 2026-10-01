import Apollo
import ApolloAPI
import Foundation

/// The Kindle connection, as the app talks to it. One place maps the generated
/// GraphQL types onto the domain model, so no screen ever touches a generated
/// type — the rule `ImportAPI` follows for Audible.
enum KindleAPI {
    /// An import reads a whole library and writes a whole shelf in one request,
    /// so it is given the function's ceiling plus a margin, as Audible's is.
    private static let importTimeout: TimeInterval = 190

    /// The connection and its library, in one request. Nil when the reader never
    /// connected — there is then no library to read, and no error either.
    static func connection() async throws -> (account: KindleAccount, library: [ImportableKindleBook])? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.KindleImportQuery()
        )
        return data.kindleAccount.map { account in
            (
                account: account.fragments.kindleAccountSummary.asDomain,
                library: account.library.map { $0.fragments.importableKindleBookFields.asDomain }
            )
        }
    }

    static func startSignIn(on marketplace: AmazonMarketplace) async throws -> AmazonLogin {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.StartKindleLoginMutation(
                marketplace: GraphQLEnum(rawValue: marketplace.rawValue)
            ),
            changesLibrary: false
        )
        let login = data.startKindleLogin
        return AmazonLogin(
            url: login.url,
            redirectURL: login.redirectUrl,
            cookies: login.cookies.map {
                AmazonLogin.Cookie(name: $0.name, value: $0.value, domain: $0.domain)
            }
        )
    }

    /// Trades the authorization code the web view caught for the connection.
    static func completeSignIn(authorizationCode: String) async throws -> KindleAccount {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.CompleteKindleLoginMutation(authorizationCode: authorizationCode),
            // Links the library; the books come with the pass that follows.
            changesLibrary: false
        )
        return data.completeKindleLogin.fragments.kindleAccountSummary.asDomain
    }

    /// Catalogues the ticked titles and returns the books created. The server
    /// re-reads the library rather than trusting these identifiers, and skips a
    /// title already catalogued — so a retry after a timeout creates no
    /// duplicate.
    static func importBooks(asins: [String]) async throws -> [Book] {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.ImportKindleLibraryMutation(asins: asins),
            requestTimeout: importTimeout
        )
        return data.importKindleLibrary.map { $0.fragments.bookSummary.asBook }
    }

    static func setAutoSync(_ enabled: Bool) async throws -> KindleAccount {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SetKindleAutoSyncMutation(enabled: enabled),
            changesLibrary: false
        )
        return data.setKindleAutoSync.fragments.kindleAccountSummary.asDomain
    }

    /// Runs the nightly pass now, whatever the switch says, and reports what it
    /// changed alongside the account it left — and the library, for the screen
    /// that lists it.
    static func syncNow(
        withLibrary: Bool = false
    ) async throws -> (outcome: SyncOutcome, account: KindleAccount, library: [ImportableKindleBook]?) {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SyncKindleNowMutation(withLibrary: withLibrary),
            requestTimeout: importTimeout
        )
        let sync = data.syncKindleNow
        return (
            SyncOutcome(imported: sync.imported, updated: sync.updated),
            sync.account.fragments.kindleAccountSummary.asDomain,
            sync.account.library?.map { $0.fragments.importableKindleBookFields.asDomain }
        )
    }

    /// Forgets our copy of the credentials. The device stays registered on the
    /// Amazon side until the reader removes it there, which the screen says.
    static func disconnect() async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DisconnectKindleMutation(),
            // Imported books stay in the library.
            changesLibrary: false
        )
    }
}

private extension ShioriGraphQL.KindleAccountSummary {
    /// A store this build does not know reads as `.com`: the library is
    /// connected either way, and the label is the only thing that suffers.
    var asDomain: KindleAccount {
        KindleAccount(
            marketplace: AmazonMarketplace(rawValue: marketplace.rawValue) ?? .com,
            connectedAt: GraphQLHelpers.parseISO8601(connectedAt),
            lastImportedAt: lastImportedAt.flatMap(GraphQLHelpers.parseISO8601),
            autoSync: autoSync,
            lastSyncFailedAt: lastSyncFailedAt.flatMap(GraphQLHelpers.parseISO8601)
        )
    }
}

private extension ShioriGraphQL.ImportableKindleBookFields {
    var asDomain: ImportableKindleBook {
        ImportableKindleBook(
            asin: asin,
            title: title,
            authors: authors,
            coverURL: coverUrl.flatMap(URL.init(string:)),
            seriesName: seriesName,
            volume: volume,
            status: status.asDomain,
            alreadyInLibrary: alreadyInLibrary
        )
    }
}
