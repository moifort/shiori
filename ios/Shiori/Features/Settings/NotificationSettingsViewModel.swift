import UserNotifications

/// The alerts the reader switched on, and whether the system lets them through.
@MainActor
@Observable
final class NotificationSettingsViewModel {
    private(set) var settings: NotificationSettings?
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var errorMessage: String?
    private(set) var saving = false

    private let client: SettingsClient

    init(client: SettingsClient) {
        self.client = client
    }

    var blocked: Bool { authorization == .denied }

    func load() async {
        authorization = await client.notificationAuthorization()
        do {
            settings = try await client.notificationSettings()
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Read again each time the app comes back, as it does from the iPhone's
    /// settings where the permission is given or taken away.
    func readAuthorization() async {
        authorization = await client.notificationAuthorization()
    }

    /// Moves the switches at once and puts them back with a message if the
    /// server refuses.
    func set(_ kinds: [AlertKind], enabled: Bool) async {
        guard let before = settings else { return }
        let changed = kinds.filter { before.enabled.contains($0) != enabled }
        guard !changed.isEmpty else { return }
        settings?.enabled = enabled ? before.enabled.union(changed) : before.enabled.subtracting(changed)
        saving = true
        defer { saving = false }
        // Switching on is when permission is worth asking for: the reader has
        // just said what they want to hear about.
        if enabled {
            await client.requestNotificationPermission()
            authorization = await client.notificationAuthorization()
        }
        do {
            for kind in changed {
                settings = try await client.setAlert(kind, enabled)
            }
        } catch {
            settings = before
            errorMessage = reportError(error)
        }
    }
}
