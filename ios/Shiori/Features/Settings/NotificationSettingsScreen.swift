import SwiftUI

/// The notification settings, connected. Shown from the settings, and as a
/// sheet from the bell in Découvrir. Read again each time the app comes back,
/// as it does from the iPhone's settings.
struct NotificationSettingsScreen: View {
    /// Set when shown as a sheet, which then closes on its leading cross.
    var onDone: (() -> Void)?

    @State private var viewModel: NotificationSettingsViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    init(onDone: (() -> Void)? = nil, client: SettingsClient = .live) {
        self.onDone = onDone
        _viewModel = State(initialValue: NotificationSettingsViewModel(client: client))
    }

    var body: some View {
        NotificationSettingsPage(
            settings: viewModel.settings,
            blocked: viewModel.blocked,
            errorMessage: viewModel.errorMessage,
            saving: viewModel.saving
        ) { action in
            switch action {
            case let .set(kind, enabled): await viewModel.set([kind], enabled: enabled)
            case let .silenceAll(silenced): await viewModel.set(AlertKind.allCases, enabled: !silenced)
            case .openSystemSettings:
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
        }
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel, action: onDone)
                }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.readAuthorization() }
        }
    }
}

#Preview {
    NavigationStack { NotificationSettingsScreen(client: .preview) }
}
