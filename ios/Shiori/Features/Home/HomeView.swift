import SwiftUI

/// The Home tab: what the reader has open right now, and nothing else above it.
///
/// No progress bar and no percentage — reading progress is not tracked, because
/// keeping it truthful would mean asking the reader to type a page number every
/// evening. What is shown instead is the shelf they are actually in.
struct HomeView: View {
    @State private var reading: [Book] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selected: Book?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && reading.isEmpty {
                    LoadingStateView()
                } else if let errorMessage, reading.isEmpty {
                    ContentUnavailableView {
                        Label("Accueil indisponible", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Réessayer") { Task { await load() } }
                    }
                } else if reading.isEmpty {
                    ContentUnavailableView {
                        Label("Aucune lecture en cours", systemImage: "book")
                    } description: {
                        Text("Passez un livre en « En cours » et il apparaîtra ici.")
                    }
                } else {
                    list
                }
            }
            .navigationTitle("En cours")
            .navigationDestination(item: $selected) { book in
                BookView(bookId: book.id, onChanged: { _ in Task { await load() } })
            }
        }
        .task { await load() }
    }

    private var list: some View {
        List(reading) { book in
            Button { selected = book } label: {
                BookRow(
                    title: book.title,
                    authorLine: book.authorLine,
                    cover: book,
                    status: book.status,
                    rating: book.rating,
                    volumeLabel: book.series?.label,
                    isHidden: book.hidden
                )
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            reading = try await LibraryAPI.currentlyReading()
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }
}
