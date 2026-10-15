import Foundation

/// What a screen connecting an Amazon source — Audible or Kindle — asks of the
/// server, as closures. The two sources take the same steps with their own
/// account and library types.
struct AmazonSourceClient<Account: Sendable, Item: Sendable>: Sendable {
    /// The account connected and its library; nil when none is.
    var connection: @Sendable () async throws -> (account: Account, library: [Item])?
    var startSignIn: @Sendable (AmazonMarketplace) async throws -> AmazonLogin
    var completeSignIn: @Sendable (_ authorizationCode: String) async throws -> Account
    var importBooks: @Sendable (_ asins: [String]) async throws -> [Book]
    var setAutoSync: @Sendable (Bool) async throws -> Account
    /// A sync run now, with the library for the screen that lists it.
    var syncNow: @Sendable () async throws -> (outcome: SyncOutcome, account: Account, library: [Item]?)
    var disconnect: @Sendable () async throws -> Void
}

typealias AudibleClient = AmazonSourceClient<AudibleAccount, ImportableBook>
typealias KindleClient = AmazonSourceClient<KindleAccount, ImportableKindleBook>

extension AmazonSourceClient where Account == AudibleAccount, Item == ImportableBook {
    static var live: Self {
        Self(
            connection: { try await ImportAPI.connection() },
            startSignIn: { try await ImportAPI.startSignIn(on: $0) },
            completeSignIn: { try await ImportAPI.completeSignIn(authorizationCode: $0) },
            importBooks: { try await ImportAPI.importBooks(asins: $0) },
            setAutoSync: { try await ImportAPI.setAutoSync($0) },
            syncNow: { try await ImportAPI.syncNow(withLibrary: true) },
            disconnect: { try await ImportAPI.disconnect() }
        )
    }
}

extension AmazonSourceClient where Account == KindleAccount, Item == ImportableKindleBook {
    static var live: Self {
        Self(
            connection: { try await KindleAPI.connection() },
            startSignIn: { try await KindleAPI.startSignIn(on: $0) },
            completeSignIn: { try await KindleAPI.completeSignIn(authorizationCode: $0) },
            importBooks: { try await KindleAPI.importBooks(asins: $0) },
            setAutoSync: { try await KindleAPI.setAutoSync($0) },
            syncNow: { try await KindleAPI.syncNow(withLibrary: true) },
            disconnect: { try await KindleAPI.disconnect() }
        )
    }
}
