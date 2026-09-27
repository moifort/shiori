import SwiftUI
import UserNotifications

/// The bell in the Découvrir toolbar: opens the release alerts as a sheet,
/// where the releases are, without a trip to the settings. Struck through
/// while nothing can reach the reader, and read again when the sheet closes.
struct DiscoverAlertsButton: View {
    @State private var silenced = false
    @State private var showsAlerts = false

    var body: some View {
        Button {
            showsAlerts = true
        } label: {
            Label("Notifications", systemImage: silenced ? "bell.slash" : "bell")
        }
        .accessibilityIdentifier("discover-alerts")
        .task { await load() }
        .sheet(isPresented: $showsAlerts, onDismiss: { Task { await load() } }) {
            NavigationStack {
                NotificationSettingsView(onDone: { showsAlerts = false })
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func load() async {
        let denied = await PushRegistrar.shared.authorizationStatus() == .denied
        let settings = try? await NotificationsAPI.settings()
        silenced = denied || (settings?.enabled.isEmpty ?? false)
    }
}
