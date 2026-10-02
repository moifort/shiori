import SwiftUI

/// The genre page, pushed from the dashboard's genre card: loads the figures
/// and hands them to the page. Reloads on any write, as the dashboard does —
/// the server works them out from the library on each read.
struct GenreInsightsView: View {
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
