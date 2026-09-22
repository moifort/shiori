import SwiftUI

/// The settings, reached from the dashboard: the account, the subscription,
/// the app itself, and the connected sources. The Audible connection lives
/// here rather than in an imports menu of its own — managing a linked account
/// is a setting, and the next source will sit beside it.
struct SettingsHomeView: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(AuthSession.self) private var authSession
    @Environment(\.dismiss) private var dismiss
    @State private var premiumShown = false
    @State private var feedbackShown = false
    @State private var openSource: ImportSource?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "person.crop.circle.fill",
                            title: "Profil",
                            subtitle: profileSubtitle,
                            tint: .blue
                        )
                    }
                    .accessibilityIdentifier("settings-profile")
                }

                Section {
                    Button {
                        premiumShown = true
                    } label: {
                        SettingsRow(
                            icon: "sparkles",
                            title: subscriptions.isPremium == true ? "Shiori Premium" : "Découvrir Premium",
                            subtitle: subscriptionSubtitle,
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-premium")
                }

                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "bell.badge.fill",
                            title: "Notifications",
                            subtitle: String(localized: "Les sorties de vos séries et de vos auteurs"),
                            tint: .red
                        )
                    }
                    .accessibilityIdentifier("settings-notifications")
                }

                Section("Sources") {
                    ForEach(ImportSource.allCases) { source in
                        Button {
                            openSource = source
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
                    NavigationLink {
                        ChangelogListView()
                    } label: {
                        SettingsRow(
                            icon: "doc.text.fill",
                            title: "Version et nouveautés",
                            subtitle: "v\(appVersion) (\(buildNumber))",
                            tint: .indigo
                        )
                    }
                    .accessibilityIdentifier("settings-changelog")
                    Button {
                        feedbackShown = true
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
            .sheet(isPresented: $premiumShown) {
                PremiumSheet(trigger: .discover)
            }
            .sheet(isPresented: $feedbackShown) {
                FeedbackSheet()
            }
            .sheet(item: $openSource) { source in
                switch source {
                case .audible:
                    AudibleImportView(onImported: { _ in openSource = nil })
                case .kindle:
                    KindleImportView(onImported: { _ in openSource = nil })
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private var profileSubtitle: String? {
        authSession.user?.displayName ?? authSession.user?.email
    }

    /// What the subscription gives today. The scan allowance is on the paywall
    /// itself, argued from the account's own numbers.
    private var subscriptionSubtitle: String? {
        switch subscriptions.isPremium {
        case true: String(localized: "Scans illimités")
        case false: String(localized: "Scannez sans compter")
        case nil: nil
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
