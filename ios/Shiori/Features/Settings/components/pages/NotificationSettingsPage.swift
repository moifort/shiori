import SwiftUI

/// Everything the notification settings can ask for.
enum NotificationSettingsAction {
    /// One alert switched on or off.
    case set(AlertKind, enabled: Bool)
    /// "Tout désactiver": on silences every alert, off turns them all back on.
    case silenceAll(Bool)
    case openSystemSettings
}

/// One switch per alert, every one of them about a book coming out and on by
/// default, and one that silences them all. If the reader refused the system
/// permission once, the page says so first and leads to the iPhone's settings,
/// the only place it can be given back, and the switches stay in sight,
/// greyed, so the reader still sees what they would get.
struct NotificationSettingsPage: View {
    /// Nil until the server answered.
    let settings: NotificationSettings?
    /// The reader refused the system permission.
    let blocked: Bool
    let errorMessage: String?
    let saving: Bool
    let onAction: (NotificationSettingsAction) async -> Void

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
                        Task { await onAction(.openSystemSettings) }
                    }
                    .accessibilityIdentifier("notification-open-system-settings")
                }
            }

            if let settings {
                Section("Me prévenir") {
                    ForEach([AlertKind.digest, .translation]) { kind in
                        Toggle(isOn: binding(settings.enabled.contains(kind)) { .set(kind, enabled: $0) }) {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                        .accessibilityIdentifier("notification-toggle-\(kind)")
                    }
                }
                .disabled(blocked)
                .opacity(blocked ? 0.5 : 1)

                Section {
                    Toggle(isOn: binding(settings.enabled.isEmpty) { .silenceAll($0) }) {
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
    }

    /// A switch showing `isOn` that turns each flip into an action.
    private func binding(
        _ isOn: Bool,
        _ action: @escaping (Bool) -> NotificationSettingsAction
    ) -> Binding<Bool> {
        Binding(get: { isOn }, set: { value in Task { await onAction(action(value)) } })
    }
}

#Preview("Allowed") {
    NavigationStack {
        NotificationSettingsPage(settings: .preview, blocked: false, errorMessage: nil, saving: false) { _ in }
    }
}

#Preview("Blocked by the system") {
    NavigationStack {
        NotificationSettingsPage(settings: .preview, blocked: true, errorMessage: nil, saving: false) { _ in }
    }
}
