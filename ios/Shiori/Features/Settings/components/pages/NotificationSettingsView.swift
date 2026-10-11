import SwiftUI
import UserNotifications

/// One switch per alert, every one of them about a book coming out and on by
/// default, and one that silences them all. Shown from the settings, and as a
/// sheet from the bell in Découvrir. The system permission is asked the first
/// time an alert is switched on; if the reader refused it once, the screen
/// says so first and leads to the system settings, the only place it can be
/// given back, and the switches stay in sight, greyed, so the reader still
/// sees what they would get. Read again each time the app comes back, as it
/// does from those settings.
struct NotificationSettingsView: View {
    /// Set when shown as a sheet, which then closes on its leading cross.
    var onDone: (() -> Void)?

    @State private var settings: NotificationSettings?
    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @State private var errorMessage: String?
    @State private var saving = false
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var blocked: Bool { authorization == .denied }

    var body: some View {
        List {
            if blocked {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications désactivées")
                                .font(.headline)
                            Text("Shiori n'est pas autorisé à vous prévenir. Activez ses notifications dans les réglages de l'iPhone pour recevoir ces alertes.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(.red)
                    }
                    .labelStyle(.row)
                    Button("Ouvrir les réglages de l'iPhone") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    .accessibilityIdentifier("notification-open-system-settings")
                }
            }

            if let settings {
                Section("Me prévenir") {
                    ForEach([AlertKind.digest, .translation]) { kind in
                        Toggle(isOn: binding(kind, in: settings)) {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                        .accessibilityIdentifier("notification-toggle-\(kind)")
                    }
                }
                .disabled(blocked)
                .opacity(blocked ? 0.5 : 1)

                Section {
                    Toggle(isOn: allOff(in: settings)) {
                        Label("Tout désactiver", systemImage: "bell.slash")
                    }
                    .accessibilityIdentifier("notification-toggle-all-off")
                }
                .disabled(blocked)
                .opacity(blocked ? 0.5 : 1)
            }
        }
        // An empty list draws no grouped background: kept here so the page
        // does not flash white while it loads.
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if settings == nil {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                } else {
                    ProgressView()
                }
            }
        }
        .disabled(saving)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel, action: onDone)
                }
            }
        }
        .task { await load() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { authorization = await PushRegistrar.shared.authorizationStatus() }
        }
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
