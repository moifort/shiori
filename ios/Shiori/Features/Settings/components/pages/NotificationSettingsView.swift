import SwiftUI
import UserNotifications

/// One switch per alert, every one of them about a book coming out and on by
/// default, and one that silences them all. Shown from the settings, and as a
/// sheet from the bell in Découvrir. The system permission is asked the first
/// time an alert is switched on; if the reader refused it once, the screen
/// says so and leads to the system settings, the only place it can be given
/// back.
struct NotificationSettingsView: View {
    /// Set when shown as a sheet, which then closes on "OK".
    var onDone: (() -> Void)?

    @State private var settings: NotificationSettings?
    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @State private var errorMessage: String?
    @State private var saving = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            if authorization == .denied {
                Section {
                    Label("Les notifications de Shiori sont désactivées dans les réglages de l'iPhone.", systemImage: "bell.slash")
                        .foregroundStyle(.secondary)
                    Button("Ouvrir les réglages") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                }
            }

            Section {
                if let settings {
                    ForEach([AlertKind.digest, .translation]) { kind in
                        Toggle(isOn: binding(kind, in: settings)) {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                        .accessibilityIdentifier("notification-toggle-\(kind)")
                    }
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                } else {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            } header: {
                Text("Me prévenir")
            } footer: {
                Text("Le dimanche soir, les tomes nouvellement annoncés dans vos séries ; puis le jour de leur sortie. Jamais pour vous faire revenir.")
            }

            if let settings {
                Section {
                    Toggle(isOn: allOff(in: settings)) {
                        Label("Tout désactiver", systemImage: "bell.slash")
                    }
                    .accessibilityIdentifier("notification-toggle-all-off")
                }
            }
        }
        .disabled(saving)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", action: onDone)
                }
            }
        }
        .task { await load() }
    }

    private func binding(_ kind: AlertKind, in settings: NotificationSettings) -> Binding<Bool> {
        Binding(
            get: { settings.enabled.contains(kind) },
            set: { value in Task { await set([kind], enabled: value) } }
        )
    }

    /// On while no alert is: switching it off turns every alert back on.
    private func allOff(in settings: NotificationSettings) -> Binding<Bool> {
        Binding(
            get: { settings.enabled.isEmpty },
            set: { value in Task { await set(AlertKind.allCases, enabled: !value) } }
        )
    }

    private func load() async {
        authorization = await PushRegistrar.shared.authorizationStatus()
        do {
            settings = try await NotificationsAPI.settings()
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Moves the switches at once and puts them back with a message if the
    /// server refuses.
    private func set(_ kinds: [AlertKind], enabled: Bool) async {
        guard let before = settings else { return }
        let changed = kinds.filter { before.enabled.contains($0) != enabled }
        guard !changed.isEmpty else { return }
        settings?.enabled = enabled ? before.enabled.union(changed) : before.enabled.subtracting(changed)
        saving = true
        defer { saving = false }
        // Switching on is when permission is worth asking for: the reader has
        // just said what they want to hear about.
        if enabled {
            _ = await PushRegistrar.shared.requestPermission()
            authorization = await PushRegistrar.shared.authorizationStatus()
        }
        do {
            for kind in changed {
                settings = try await NotificationsAPI.setAlert(kind, enabled: enabled)
            }
        } catch {
            settings = before
            errorMessage = reportError(error)
        }
    }
}

#Preview {
    NavigationStack { NotificationSettingsView() }
}
