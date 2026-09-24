import SwiftUI
import UserNotifications

/// One switch per alert, every one of them about a book coming out and on by
/// default. The system permission is asked the first time the Découvrir tab has
/// a release to announce, or one is switched on here; if the reader
/// refused it once, the screen says so and leads to the system settings, the
/// only place it can be given back.
struct NotificationSettingsView: View {
    @State private var settings: NotificationSettings?
    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @State private var errorMessage: String?
    @State private var saving: Set<AlertKind> = []
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            if authorization == .denied {
                Section {
                    Label("Les notifications de Shiori sont désactivées dans les réglages de l'iPhone.", systemImage: "bell.slash")
                        .foregroundStyle(.secondary)
                    Button("Ouvrir les réglages") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }

            Section {
                if let settings {
                    ForEach(AlertKind.allCases) { kind in
                        toggle(kind, enabled: settings.enabled.contains(kind))
                    }
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                } else {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            } header: {
                Text("Me prévenir")
            } footer: {
                Text("Shiori vous prévient le jour de la sortie, jamais pour vous faire revenir. Les dates viennent de l'onglet Découvrir, mis à jour chaque jour.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func toggle(_ kind: AlertKind, enabled: Bool) -> some View {
        Toggle(isOn: .init(get: { enabled }, set: { value in Task { await set(kind, value) } })) {
            Label(kind.title, systemImage: kind.symbol)
        }
        .disabled(saving.contains(kind))
        .accessibilityIdentifier("notification-toggle")
    }

    private func load() async {
        authorization = await PushRegistrar.shared.authorizationStatus()
        do {
            settings = try await NotificationsAPI.settings()
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func set(_ kind: AlertKind, _ enabled: Bool) async {
        saving.insert(kind)
        defer { saving.remove(kind) }
        // Switching on is when permission is worth asking for: the reader has
        // just said what they want to hear about.
        if enabled {
            _ = await PushRegistrar.shared.requestPermission()
            authorization = await PushRegistrar.shared.authorizationStatus()
        }
        do {
            settings = try await NotificationsAPI.setAlert(kind, enabled: enabled)
        } catch {
            errorMessage = reportError(error)
        }
    }
}

#Preview {
    NavigationStack { NotificationSettingsView() }
}
