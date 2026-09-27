import SwiftUI
import UserNotifications

/// The bell in the Découvrir toolbar: the two release alerts switched on or
/// off where the releases are, without a trip to the settings. Switching one
/// on is when the system permission is asked, as on the settings screen; a
/// permission refused once can only be given back in the iPhone's settings,
/// which "Configurer" opens. The bell is struck through while nothing can
/// reach the reader.
struct DiscoverAlertsMenu: View {
    @State private var settings: NotificationSettings?
    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @State private var saving = false
    @State private var showsSettings = false
    @State private var errorMessage: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        Menu {
            Section("Me prévenir") {
                ForEach([AlertKind.digest, .translation]) { kind in
                    Toggle(isOn: binding(kind)) {
                        Label(kind.title, systemImage: kind.symbol)
                    }
                    .accessibilityIdentifier("discover-alert-\(kind)")
                }
            }
            Section {
                if !(settings?.enabled.isEmpty ?? true) {
                    Button("Tout désactiver", systemImage: "bell.slash", role: .destructive) {
                        Task { await set(AlertKind.allCases, enabled: false) }
                    }
                    .accessibilityIdentifier("discover-alerts-off")
                }
                Button("Configurer les notifications…", systemImage: "gearshape") {
                    Task { await setUp() }
                }
                .accessibilityIdentifier("discover-alerts-setup")
            }
        } label: {
            Label("Notifications", systemImage: symbol)
        }
        .disabled(saving)
        .accessibilityIdentifier("discover-alerts")
        .task { await load() }
        .navigationDestination(isPresented: $showsSettings) { NotificationSettingsView() }
        .alert(
            "Réglage non enregistré",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            presenting: errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    /// Struck through when no alert is on or the iPhone refuses them all.
    private var symbol: String {
        guard let settings, !settings.enabled.isEmpty, authorization != .denied else {
            return "bell.slash"
        }
        return "bell"
    }

    private func binding(_ kind: AlertKind) -> Binding<Bool> {
        Binding(
            get: { settings?.enabled.contains(kind) ?? false },
            set: { value in Task { await set([kind], enabled: value) } }
        )
    }

    private func load() async {
        authorization = await PushRegistrar.shared.authorizationStatus()
        settings = try? await NotificationsAPI.settings()
    }

    /// Moves the switches at once, so the bell and the menu answer the tap,
    /// and puts them back with a message if the server refuses.
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

    /// Asks for the permission the first time, sends the reader to the
    /// iPhone's settings once it was refused, and otherwise opens the alerts'
    /// own settings screen.
    private func setUp() async {
        switch authorization {
        case .notDetermined:
            _ = await PushRegistrar.shared.requestPermission()
            authorization = await PushRegistrar.shared.authorizationStatus()
        case .denied:
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
        default:
            showsSettings = true
        }
    }
}
