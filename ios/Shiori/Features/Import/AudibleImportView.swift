import SwiftUI

/// The Audible source's coordinator: owns the view model, the navigation stack
/// and the sign-in sheet, and maps between the domain and the pure pages below
/// it — the shape the Library tab already has.
///
/// Opens on the source card, not on the picker. A connected library keeps itself
/// up to date, so what a reader comes here to do is check on it; ticking titles
/// is one push further in.
struct AudibleImportView: View {
    /// Called with the books that were catalogued, so the library refreshes
    /// itself without a second round trip. Not called when nothing was imported.
    let onImported: ([Book]) -> Void

    /// The one screen that is pushed rather than shown. An enum for it because the
    /// next import source will push its own.
    private enum Step: Hashable {
        case pickBooks
    }

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AudibleImportViewModel()
    @State private var path: [Step] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .pickBooks: picker
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                    }
                }
        }
        // Keyed on the login itself: a second attempt carries a new PKCE
        // challenge, and re-presenting the sheet is what loads the new page.
        .sheet(item: $viewModel.signIn) { login in
            signInSheet(login)
        }
        .alert(
            "Une erreur est survenue",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let account = viewModel.account {
            AudibleSourcePage(
                account: account,
                totalCount: viewModel.totalCount,
                catalogedCount: viewModel.catalogedCount,
                isLoading: viewModel.isLoading,
                isSyncing: viewModel.isSyncing,
                lastSyncOutcome: viewModel.lastSyncOutcome,
                onAutoSyncChange: { enabled in Task { await viewModel.setAutoSync(enabled) } },
                onSyncNow: { Task { await viewModel.syncNow() } },
                onPickBooks: { path.append(.pickBooks) },
                onDisconnect: {
                    // Popped first: the picker behind this card has no account to
                    // stand on once the connection is gone.
                    path = []
                    await viewModel.disconnect()
                }
            )
        } else {
            AudibleConnectPage(
                marketplace: $viewModel.marketplace,
                isWorking: viewModel.isLoading,
                onConnect: { Task { await viewModel.startSignIn() } }
            )
        }
    }

    private var picker: some View {
        AudibleLibraryPage(
            books: viewModel.books,
            isLoading: viewModel.isLoading,
            isImporting: viewModel.isImporting,
            selectedCount: viewModel.selected.count,
            canImport: viewModel.canImport,
            // Wrapped rather than passed as method references: the pages take
            // plain closures, and handing them a main-actor-isolated function
            // would drop its isolation.
            isSelected: { viewModel.isSelected($0) },
            onToggle: { viewModel.toggle($0) },
            onSelectAll: { viewModel.selectAll() },
            onDeselectAll: { viewModel.deselectAll() },
            onImport: {
                Task {
                    let imported = await viewModel.importSelected()
                    guard !imported.isEmpty else { return }
                    onImported(imported)
                    dismiss()
                }
            }
        )
    }

    private func signInSheet(_ login: AudibleLogin) -> some View {
        NavigationStack {
            AmazonSignInWebView(login: login) { code in
                Task { await viewModel.finishSignIn(code: code) }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Connexion Amazon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { viewModel.cancelSignIn() }
                }
            }
        }
    }
}
