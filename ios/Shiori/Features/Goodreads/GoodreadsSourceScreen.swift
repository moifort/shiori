import SwiftUI

/// Goodreads in the settings, connected: reads the last import and opens the
/// import, from its first page or straight on the file picker's.
struct GoodreadsSourceScreen: View {
    var onClose: () -> Void

    @State private var summary: GoodreadsImportSummary?
    @State private var isLoading = true
    @State private var importing = false

    var body: some View {
        NavigationStack {
            GoodreadsSourcePage(
                summary: summary,
                isLoading: isLoading,
                onImport: { importing = true },
                onHowTo: { importing = true }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel, action: onClose)
                }
            }
        }
        .task { await load() }
        .fullScreenCover(isPresented: $importing) {
            GoodreadsImportScreen(mode: .settings) { _ in
                importing = false
                Task { await load() }
            }
        }
    }

    private func load() async {
        defer { isLoading = false }
        do {
            summary = try await GoodreadsAPI.lastImport()
        } catch {
            _ = reportError(error)
        }
    }
}
