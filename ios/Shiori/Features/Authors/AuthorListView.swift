import SwiftUI

/// The Authors shelf of the Library tab: every author the reader holds a book
/// of, the ones they love first — most hearts, then the best stars, then the
/// most books. No favourites view: the order already puts the loved authors
/// first.
///
/// The order comes from the server: the list is paginated, and ordered on the
/// phone it would reshuffle every time a page landed. There are no month
/// sections, since the list is not ordered by date.
///
/// A row opens the author's page, as a sheet.
struct AuthorListView: View {
    /// Opens the add sheet, from the one button every empty state offers.
    var onScan: () -> Void = {}
    /// The shelf capsule of the Library tab, drawn under the list.
    var shelf: Binding<LibraryShelf>? = nil

    @State private var viewModel = AuthorListViewModel()
    /// The author being opened. A tap and a destination rather than a
    /// navigation link, as on the Series tab: a link would claim the drag that
    /// scrolls the covers, and draw a chevron on every row.
    @State private var openAuthor: AuthorDestination?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.authors.isEmpty {
                    ProgressView("Chargement de vos auteurs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.authors.isEmpty {
                    EmptyStateView.failure("Auteurs indisponibles", message: errorMessage) {
                        await viewModel.load()
                    }
                } else if viewModel.authors.isEmpty {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: "Aucun auteur",
                        message: "Scannez un livre et son auteur apparaîtra ici, avec tous ses livres.",
                        primary: .init("Scanner un livre", systemImage: "camera") { onScan() }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Auteurs")
            .libraryShelfPicker(shelf)
            // Over last session's snapshot when the disk had one: the rows show
            // at once and are brought up to date underneath.
            .task { await viewModel.loadOnAppear() }
        }
        // A book finished, a heart given, a book scanned: the rows here say so
        // the next time the reader looks — all of them, so the reader stays
        // where they were, and a loved author climbs into place.
        .onReceive(NotificationCenter.default.publisher(for: .shioriDataDidChange)) { _ in
            Task { await viewModel.load(keepingDepth: true) }
        }
        // An author's first opening builds their catalogue, portrait included,
        // and nothing posts a change for that: the rows are asked again when
        // the reader comes back, so the portrait replaces the initials.
        .onChange(of: openAuthor) { closed, opened in
            guard closed != nil, opened == nil else { return }
            Task { await viewModel.load(keepingDepth: true) }
        }
    }

    private var list: some View {
        List {
            // The snapshot on screen is brought up to date silently. Only a
            // refresh that failed says so, since the rows are then last time's.
            if viewModel.refreshFailed {
                RefreshRow(
                    failed: viewModel.refreshFailed,
                    loadingLabel: "Mise à jour des auteurs",
                    onRetry: { await viewModel.refresh() }
                )
            }
            Section {
                ForEach(viewModel.authors) { author in
                    AuthorRow(author: author)
                        .contentShape(Rectangle())
                        .onTapGesture { openAuthor = AuthorDestination(author) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { openAuthor = AuthorDestination(author) }
                        .edgeToEdgeSeparator()
                        .accessibilityIdentifier("author-row")
                        .onAppear { viewModel.prefetchIfNeeded(for: author.id) }
                }
            }
            if viewModel.hasMore {
                LoadMoreRow(
                    failed: viewModel.loadMoreFailed,
                    loadingLabel: "Chargement de la suite",
                    onLoadMore: { await viewModel.loadMore() }
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.load() }
        // A sheet, as a book opens from the library and a saga from Découvrir:
        // the same corners on an author. Its own stack, so a saga pushes inside it.
        .sheet(item: $openAuthor) { opened in
            NavigationStack {
                AuthorView(key: opened.key, name: opened.name, isSheet: true)
            }
        }
    }
}

/// The author a row opens: the key the page is asked by, and the name its
/// title shows while it loads.
struct AuthorDestination: Hashable, Identifiable {
    let key: String
    let name: String
    var id: String { key }

    init(_ author: FollowedAuthor) {
        key = author.key
        name = author.name
    }
}
