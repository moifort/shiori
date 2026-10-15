import SwiftUI

/// Where a row of the settings leads, pushed by the screen.
enum SettingsDestination: Hashable {
    case profile
    case notifications
    case changelog
}

/// Everything the settings page can ask for, besides the rows it pushes.
enum SettingsHomeAction {
    case showPremium
    case showFeedback
    case openSource(ImportSource)
}

/// The settings, reached from the dashboard: the account, the subscription,
/// the app itself, and the connected sources. The Audible connection lives
/// here rather than in an imports menu of its own — managing a linked account
/// is a setting, and the next source will sit beside it.
struct SettingsHomePage: View {
    /// Who the account is, under "Profil".
    let profileSubtitle: String?
    /// Nil until the store answered.
    let isPremium: Bool?
    /// The reader refused the system permission for notifications.
    let notificationsBlocked: Bool
    let appVersion: String
    let buildNumber: String
    let onAction: (SettingsHomeAction) -> Void

    var body: some View {
        List {
            Section {
                NavigationLink(value: SettingsDestination.profile) {
                    SettingsRow(
                        icon: "person.crop.circle.fill",
                        title: "Profil",
                        subtitle: profileSubtitle,
                        tint: .blue
                    )
                }
                .accessibilityIdentifier("settings-profile")

                Button {
                    onAction(.showPremium)
                } label: {
                    SettingsRow(
                        icon: "sparkles",
                        title: isPremium == true ? "Shiori Premium" : "Découvrir Premium",
                        subtitle: subscriptionSubtitle,
                        tint: .orange
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-premium")

                NavigationLink(value: SettingsDestination.notifications) {
                    SettingsRow(
                        icon: notificationsBlocked ? "bell.slash.fill" : "bell.badge.fill",
                        title: "Notifications",
                        subtitle: notificationsBlocked
                            ? String(localized: "Désactivées dans les réglages de l'iPhone")
                            : String(localized: "Prochaine sortie et nouvelle disponibilité"),
                        tint: .red
                    )
                }
                .accessibilityIdentifier("settings-notifications")
            }

            Section("Sources") {
                ForEach(ImportSource.allCases) { source in
                    Button {
                        onAction(.openSource(source))
                    } label: {
                        SettingsRow(
                            icon: source.symbol,
                            title: LocalizedStringKey(source.label),
                            subtitle: source.subtitle,
                            tint: .teal
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-source-\(source.rawValue)")
                }
            }

            Section("Application") {
                NavigationLink(value: SettingsDestination.changelog) {
                    SettingsRow(
                        icon: "doc.text.fill",
                        title: "Version et nouveautés",
                        subtitle: "v\(appVersion) (\(buildNumber))",
                        tint: .indigo
                    )
                }
                .accessibilityIdentifier("settings-changelog")
                Button {
                    onAction(.showFeedback)
                } label: {
                    SettingsRow(
                        icon: "envelope.fill",
                        title: "Nous écrire",
                        subtitle: String(localized: "Signaler un problème ou proposer une idée"),
                        tint: .pink
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-feedback")
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// What the subscription gives today. The scan allowance is on the paywall
    /// itself, argued from the account's own numbers.
    private var subscriptionSubtitle: String? {
        switch isPremium {
        case true: String(localized: "Scans illimités")
        case false: String(localized: "Scannez sans compter")
        case nil: nil
        }
    }
}

#Preview {
    NavigationStack {
        SettingsHomePage(
            profileSubtitle: "lecteur@example.com", isPremium: false, notificationsBlocked: false,
            appVersion: "1.4", buildNumber: "212"
        ) { _ in }
    }
}

#Preview("Premium, notifications blocked") {
    NavigationStack {
        SettingsHomePage(
            profileSubtitle: nil, isPremium: true, notificationsBlocked: true,
            appVersion: "1.4", buildNumber: "212"
        ) { _ in }
    }
}
