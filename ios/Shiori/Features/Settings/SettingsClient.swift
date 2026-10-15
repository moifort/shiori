import UserNotifications

/// Everything the settings screens ask of the server and of the system, as
/// closures: `.live` goes through the APIs and `PushRegistrar`, `.preview`
/// answers at once, and a test builds the one it needs inline.
struct SettingsClient: Sendable {
    var changelog: @Sendable () async throws -> [ChangelogEntry]
    var deleteAccount: @Sendable () async throws -> Void
    /// After a deletion that seemed to fail: true when the account is gone
    /// all the same, and the session has been dropped.
    var accountIsGone: @Sendable () async -> Bool
    var notificationSettings: @Sendable () async throws -> NotificationSettings
    var setAlert: @Sendable (AlertKind, _ enabled: Bool) async throws -> NotificationSettings
    var notificationAuthorization: @Sendable () async -> UNAuthorizationStatus
    var requestNotificationPermission: @Sendable () async -> Void
    /// Stops the server pushing to this phone, before the session ends.
    var forgetDevice: @Sendable () async -> Void
}

extension SettingsClient {
    static let live = SettingsClient(
        changelog: { try await SettingsAPI.changelog() },
        deleteAccount: { try await SettingsAPI.deleteAccount() },
        accountIsGone: { await AuthSession.dropSessionIfAccountIsGone() },
        notificationSettings: { try await NotificationsAPI.settings() },
        setAlert: { try await NotificationsAPI.setAlert($0, enabled: $1) },
        notificationAuthorization: { await PushRegistrar.shared.authorizationStatus() },
        requestNotificationPermission: { _ = await PushRegistrar.shared.requestPermission() },
        forgetDevice: { await PushRegistrar.shared.forgetDevice() }
    )

    static let preview = SettingsClient(
        changelog: { ChangelogEntry.previews },
        deleteAccount: {},
        accountIsGone: { false },
        notificationSettings: { .preview },
        setAlert: { kind, enabled in
            var settings = NotificationSettings.preview
            if enabled { settings.enabled.insert(kind) } else { settings.enabled.remove(kind) }
            return settings
        },
        notificationAuthorization: { .authorized },
        requestNotificationPermission: {},
        forgetDevice: {}
    )
}

extension ChangelogEntry {
    static let previews = [
        ChangelogEntry(version: "1.4", date: nil, notes: ["Les découvertes du mois arrivent sur l'accueil."]),
        ChangelogEntry(
            version: "1.3",
            date: .now.addingTimeInterval(-86400 * 12),
            notes: ["Les prix littéraires dans Découvrir.", "Le défi lecture entre amis."]
        ),
    ]
}

extension NotificationSettings {
    static let preview = NotificationSettings(enabled: [.translation], deviceCount: 1)
}
