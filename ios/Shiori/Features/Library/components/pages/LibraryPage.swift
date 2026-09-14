import SwiftUI

/// The library list. Pure and previewable: it takes what to draw and what to
/// call, and knows nothing about the network.
///
/// Sections are sagas. The standalone shelf trails them with no heading, because
/// it is the leftovers rather than a category — giving it a title like "Autres"
/// would make it look like a shelf the reader chose.
struct LibraryPage: View {
    let sections: [LibrarySection]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var filter: ReadingStatus?
    let onSelect: (Book) -> Void
    let onRetry: () -> Void
    let onAddManually: () -> Void

    var body: some View {
        Group {
            if isLoading && sections.isEmpty {
                LoadingStateView(label: "Chargement de votre bibliothèque...")
            } else if let errorMessage, sections.isEmpty {
                ContentUnavailableView {
                    Label("Bibliothèque indisponible", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Réessayer", action: onRetry)
                }
            } else if sections.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Bibliothèque")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filtrer", selection: $filter) {
                        Text("Tout").tag(ReadingStatus?.none)
                        ForEach(ReadingStatus.allCases) { status in
                            Label(status.label, systemImage: status.symbol)
                                .tag(ReadingStatus?.some(status))
                        }
                    }
                } label: {
                    Label("Filtrer", systemImage: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityIdentifier("library-filter")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddManually) {
                    Label("Ajouter un livre", systemImage: "plus")
                }
                .accessibilityIdentifier("library-add")
            }
        }
    }

    private var list: some View {
        List {
            ForEach(sections) { section in
                if let name = section.seriesName {
                    Section(name) { rows(of: section) }
                } else {
                    Section { rows(of: section) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { onRetry() }
    }

    private func rows(of section: LibrarySection) -> some View {
        ForEach(section.books) { book in
            Button { onSelect(book) } label: {
                BookRow(
                    title: book.title,
                    authorLine: book.authorLine,
                    cover: book,
                    status: book.status,
                    rating: book.rating,
                    // Only inside a saga: on the standalone shelf there is no
                    // numbering for a label to explain.
                    volumeLabel: section.seriesName != nil ? book.series?.label : nil,
                    isHidden: book.hidden
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let filter {
            ContentUnavailableView {
                Label("Rien ici", systemImage: filter.symbol)
            } description: {
                Text("Aucun livre au statut « \(filter.label) ».")
            } actions: {
                Button("Voir toute la bibliothèque") { self.filter = nil }
            }
        } else {
            ContentUnavailableView {
                Label("Bibliothèque vide", systemImage: "books.vertical")
            } description: {
                Text("Scannez la couverture d'un livre, ou ajoutez-en un à la main.")
            } actions: {
                Button("Ajouter à la main", action: onAddManually)
            }
        }
    }
}

#Preview("Avec des livres") {
    @Previewable @State var filter: ReadingStatus?
    let saga = SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main)
    let saga2 = SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 2, kind: .main)

    return NavigationStack {
        LibraryPage(
            sections: [
                LibrarySection(
                    seriesId: "s1",
                    seriesName: "Chronique du tueur de roi",
                    books: [
                        Book(id: "1", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], series: saga, status: .read, rating: 5),
                        Book(id: "2", title: "La Peur du sage", authors: ["Patrick Rothfuss"], series: saga2, status: .reading),
                    ]
                ),
                LibrarySection(
                    seriesId: nil,
                    seriesName: nil,
                    books: [
                        Book(id: "3", title: "Piranesi", authors: ["Susanna Clarke"], status: .toRead, hidden: true),
                    ]
                ),
            ],
            isLoading: false,
            errorMessage: nil,
            filter: $filter,
            onSelect: { _ in },
            onRetry: {},
            onAddManually: {}
        )
    }
}

#Preview("Vide") {
    @Previewable @State var filter: ReadingStatus?
    NavigationStack {
        LibraryPage(
            sections: [],
            isLoading: false,
            errorMessage: nil,
            filter: $filter,
            onSelect: { _ in },
            onRetry: {},
            onAddManually: {}
        )
    }
}
