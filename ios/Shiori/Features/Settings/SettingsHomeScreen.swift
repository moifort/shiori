import SwiftUI

/// The settings, connected: the account from the auth session, the
/// subscription from the store, the notification permission read on opening
/// and each time the app comes back, and every sheet and push of
/// `SettingsHomePage`.
struct SettingsHomeScreen: View {
    var client: SettingsClient = .live

    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(AuthSession.self) private var authSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var premiumShown = false
    @State private var feedbackShown = false
    @State private var openSource: ImportSource?
    @State private var notificationsBlocked = false

    var body: some View {
        NavigationStack {
            SettingsHomePage(
                profileSubtitle: authSession.user?.displayName ?? authSession.user?.email,
                isPremium: subscriptions.isPremium,
                notificationsBlocked: notificationsBlocked,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
            ) { action in
                switch action {
                case .showPremium: premiumShown = true
                case .showFeedback: feedbackShown = true
                case let .openSource(source): openSource = source
                }
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .profile: ProfileSettingsScreen(client: client)
                case .notifications: NotificationSettingsScreen(client: client)
                case .changelog: ChangelogScreen(client: client)
                }
            }
            .sheet(isPresented: $premiumShown) {
                PremiumSheet(trigger: .discover)
            }
            .sheet(isPresented: $feedbackShown) {
                FeedbackSheet(onSend: sendFeedback)
            }
            .sheet(item: $openSource) { source in
                switch source {
                case .audible:
                    AudibleImportScreen(onImported: { _ in openSource = nil })
                case .kindle:
                    KindleImportScreen(onImported: { _ in openSource = nil })
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            .task { await readNotificationPermission() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await readNotificationPermission() } }
            }
        }
    }

    /// Read on opening and again when the app comes back, as it does from the
    /// iPhone's settings where the permission is given or taken away.
    private func readNotificationPermission() async {
        notificationsBlocked = await client.notificationAuthorization() == .denied
    }
}
