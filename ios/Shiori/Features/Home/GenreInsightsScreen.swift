import SwiftUI

/// The genre page, opened from the dashboard's genre card as a sheet, like a
/// book: loads the figures and hands them to `GenreInsightsPage`. Reloads on
/// any write, as the dashboard does — the server works them out from the
/// library on each read.
struct GenreInsightsScreen: View {
    /// Reads the figures.
    let load: () async throws -> GenreInsights

    @Environment(\.dismiss) private var dismiss
    @State private var insights: GenreInsights?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let insights {
                GenreInsightsPage(insights: insights)
            } else if let errorMessage {
                EmptyStateView.failure("Genres indisponibles", message: errorMessage) { await reload() }
                    .navigationTitle("Genres lus")
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Genres lus")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
        }
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        errorMessage = nil
        do {
            insights = try await load()
        } catch {
            errorMessage = reportError(error)
        }
    }
}
