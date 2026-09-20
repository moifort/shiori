import SwiftUI

/// The Series tab: the sagas the reader follows, each in progress or complete.
///
/// No counter. "2 sur 14" reads as a scoreboard on a list whose purpose is to
/// let the reader pick a saga and get back into it — the state is what tells
/// them whether there is anything left to read.
///
/// A saga nobody has catalogued has no state to show: what it has instead is
/// how many volumes are on the shelf. That is a fact about the library, not a
/// score out of a total nobody knows.
struct SeriesListView: View {
    @State private var followed: [FollowedSeries] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && followed.isEmpty {
                    ProgressView("Chargement de vos séries...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            NavigationLink(value: entry.seriesId) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(entry.name).font(.body.weight(.medium))
                        // Which of the saga's two shelves this row is. Trailing
                        // the name, as in the library headings: the name is what
                        // the reader scans for, and only foreign, as there too.
                        if let language = entry.language, language.isForeign {
                            Text(language.flag).accessibilityLabel(Text(language.label))
                        }
                        Spacer(minLength: 0)
                        if entry.opinion?.favorite == true {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.pink)
                                .accessibilityLabel(Text("Favori"))
                        }
                    }
                    if let rating = entry.opinion?.rating {
                        StarRatingView(rating: rating)
                    }
                    if let author = entry.author {
                        Text(author).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let state = entry.state {
                        Label(
                            state.label,
                            systemImage: state == .complete ? "checkmark.circle.fill" : "book"
                        )
                        .font(.caption)
                        .foregroundStyle(state == .complete ? Color.green : .secondary)
                        .padding(.top, 1)
                    } else {
                        Label(
                            "\(entry.ownedCount) tome(s)",
                            systemImage: "books.vertical"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                    }
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
            errorMessage = reportError(error)
        }
        isLoading = false
    }
}
