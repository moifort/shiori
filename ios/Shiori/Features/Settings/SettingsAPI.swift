import Foundation

/// One released version and what it changed, as the app shows it.
struct ChangelogEntry: Identifiable, Sendable {
    var id: String { version }
    let version: String
    let date: Date?
    let notes: [String]
}

enum SettingsAPI {
    /// The release notes, served in the caller's language by the backend.
    static func changelog() async throws -> [ChangelogEntry] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.ChangelogQuery()
        )
        return data.changelog.map { entry in
            ChangelogEntry(
                version: entry.version,
                date: entry.date.flatMap(GraphQLHelpers.parseISO8601),
                notes: entry.notes
            )
        }
    }

    /// Erases the account and everything it owns, then the Firebase identity.
    /// Irreversible, and required by App Review for any app that creates an
    /// account. Does NOT cancel an App Store subscription — Apple owns that
    /// lifecycle, which is why the screen says so before asking.
    static func deleteAccount() async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.DeleteAccountMutation(),
            changesLibrary: false
        )
    }
}
