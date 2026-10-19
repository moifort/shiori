import Foundation

/// The alerts a reader can switch off; every one starts on. Each says something
/// new: a book coming out, or the month's discoveries made.
enum AlertKind: CaseIterable, Identifiable, Sendable {
    /// Stored as `translation` for what it first announced: a new volume of a
    /// saga the reader follows, the day it comes out.
    case translation
    /// The Sunday digest of the volumes newly announced.
    case digest
    /// The month's discoveries, made on the first.
    case discoveries
    var id: Self { self }

    var title: String {
        switch self {
        case .translation: String(localized: "Nouvelle sortie")
        case .digest: String(localized: "Nouveauté hebdomadaire")
        case .discoveries: String(localized: "Découvertes du mois")
        }
    }

    var symbol: String {
        switch self {
        case .translation: "book.closed"
        case .digest: "calendar"
        case .discoveries: "sparkles"
        }
    }

    var graphQL: ShioriGraphQL.AlertKind {
        switch self {
        case .translation: .translation
        case .digest: .digest
        case .discoveries: .discoveries
        }
    }

    init?(graphQL kind: ShioriGraphQL.AlertKind) {
        switch kind {
        case .translation: self = .translation
        case .digest: self = .digest
        case .discoveries: self = .discoveries
        }
    }
}

/// What the reader switched on, and whether any device of theirs can hear it.
struct NotificationSettings: Sendable {
    var enabled: Set<AlertKind>
    var deviceCount: Int
}

enum NotificationsAPI {
    static func settings() async throws -> NotificationSettings {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.NotificationSettingsQuery()
        )
        return NotificationSettings(fields: data.notificationSettings.fragments.notificationSettingsFields)
    }

    static func setAlert(_ kind: AlertKind, enabled: Bool) async throws -> NotificationSettings {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SetAlertMutation(kind: .case(kind.graphQL), enabled: enabled),
            changesLibrary: false
        )
        return NotificationSettings(fields: data.setAlert.fragments.notificationSettingsFields)
    }

    static func registerDevice(token: String, sandbox: Bool) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.RegisterDeviceMutation(
                token: token,
                environment: .case(sandbox ? .sandbox : .production)
            ),
            changesLibrary: false
        )
    }

    static func unregisterDevice(token: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.UnregisterDeviceMutation(token: token),
            changesLibrary: false
        )
    }
}

private extension NotificationSettings {
    init(fields: ShioriGraphQL.NotificationSettingsFields) {
        self.init(
            enabled: Set(fields.alerts.compactMap { alert in
                guard alert.enabled, let kind = alert.kind.value else { return nil }
                return AlertKind(graphQL: kind)
            }),
            deviceCount: fields.deviceCount
        )
    }
}
