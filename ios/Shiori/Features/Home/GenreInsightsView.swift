import SwiftUI

/// The genre page, opened from the dashboard's genre card as a sheet, like a
/// book: loads the figures and hands them to the page. Reloads on any write, as the dashboard does —
/// the server works them out from the library on each read.
struct GenreInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var insights: GenreInsights?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let insights {
                GenreInsightsPage(insights: insights)
            } else if let errorMessage {
                EmptyStateView.failure("Genres indisponibles", message: errorMessage) { await load() }
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
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        errorMessage = nil
        do {
            insights = try await HomeAPI.genreInsights()
        } catch {
            errorMessage = reportError(error)
        }
    }
}
