import SwiftUI

/// The Series tab: the sagas the reader follows, each in progress or complete.
///
/// No counter. "2 sur 14" reads as a scoreboard on a list whose purpose is to
/// let the reader pick a saga and get back into it — the state is what tells
/// them whether there is anything left to read.
struct SeriesListView: View {
    @State private var followed: [FollowedSeries] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && followed.isEmpty {
                    LoadingStateView(label: "Chargement de vos séries...")
                } else if let errorMessage, followed.isEmpty {
                    ContentUnavailableView {
                        Label("Séries indisponibles", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Réessayer") { Task { await load() } }
                    }
                } else if followed.isEmpty {
                    ContentUnavailableView {
                        Label("Aucune série", systemImage: "square.stack")
                    } description: {
                        Text("Scannez un tome d'une saga et elle apparaîtra ici, avec tous ses volumes.")
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Séries")
        }
        .task { await load() }
    }

    private var list: some View {
        List(followed) { entry in
            NavigationLink(value: entry.series.id) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.series.name).font(.body.weight(.medium))
                    Text(entry.series.author).font(.subheadline).foregroundStyle(.secondary)
                    Label(
                        entry.state.label,
                        systemImage: entry.state == .complete ? "checkmark.circle.fill" : "book"
                    )
                    .font(.caption)
                    .foregroundStyle(entry.state == .complete ? Color.green : .secondary)
                    .padding(.top, 1)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
        .navigationDestination(for: String.self) { SeriesView(seriesId: $0) }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            followed = try await SeriesAPI.mySeries()
        } catch {
            errorMessage = ErrorPresenter.message(for: error)
        }
        isLoading = false
    }
}
