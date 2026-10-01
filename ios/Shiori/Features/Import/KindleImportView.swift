import SwiftUI

/// The Kindle source's coordinator: owns the view model, the navigation stack
/// and the sign-in sheet, and maps between the domain and the pure pages below
/// it — the shape `AudibleImportView` has.
///
/// Opens on the source card, not on the picker: a connected library keeps
/// itself up to date, so what a reader comes here to do is check on it.
struct KindleImportView: View {
    /// Called with the books that were catalogued, so the library refreshes
    /// itself. Not called when nothing was imported.
    let onImported: ([Book]) -> Void

    private enum Step: Hashable {
        case pickBooks
    }

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = KindleImportViewModel()
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
            AmazonSignInSheet(login: login, onCode: { code in
                Task { await viewModel.finishSignIn(code: code) }
            }, onCancel: { viewModel.cancelSignIn() })
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
            KindleSourcePage(
                account: account,
                totalCount: viewModel.totalCount,
                catalogedCount: viewModel.catalogedCount,
                isLoading: viewModel.isLoading,
                isSyncing: viewModel.isSyncing,
                lastSyncOutcome: viewModel.lastSyncOutcome,
                onAutoSyncChange: { enabled in Task { await viewModel.setAutoSync(enabled) } },
                onSyncNow: { Task { await viewModel.syncNow() } },
                onPickBooks: { path.append(.pickBooks) },
                onReconnect: { Task { await viewModel.startSignIn() } },
                onDisconnect: {
                    path = []
                    await viewModel.disconnect()
                }
            )
        } else {
            KindleConnectPage(
                marketplace: $viewModel.marketplace,
                isWorking: viewModel.isLoading,
                onConnect: { Task { await viewModel.startSignIn() } }
            )
        }
    }

    private var picker: some View {
        KindleLibraryPage(
            books: viewModel.books,
            isLoading: viewModel.isLoading,
            isImporting: viewModel.isImporting,
            selectedCount: viewModel.selected.count,
            canImport: viewModel.canImport,
            // Wrapped rather than passed as method references, which would drop
            // their main-actor isolation.
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
}
