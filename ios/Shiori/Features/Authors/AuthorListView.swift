import SwiftUI

/// The Authors shelf of the Library tab: every author the reader holds a book
/// of, listed two ways from the toolbar. By name, as the Contacts app lists
/// people: a section per letter of their surname and the alphabet down the
/// side to jump to one. Or the ones they love first — most hearts, then the
/// best stars, then the most books.
///
/// Both orders come from the server, which files an author under their
/// surname the way a bookshop does. There are no month sections, since
/// neither order is by date.
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
            .navigationSubtitle(viewModel.order.subtitle)
            .toolbar { toolbar }
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
            switch viewModel.order {
            case .name:
                ForEach(letters, id: \.letter) { section in
                    Section(section.letter) {
                        ForEach(section.authors) { author in row(author) }
                    }
                    .sectionIndexLabel(section.letter)
                }
            case .loved:
                Section {
                    ForEach(viewModel.authors) { author in row(author) }
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
        .listSectionIndexVisibility(viewModel.order == .name ? .visible : .hidden)
        .refreshable { await viewModel.load() }
        // A sheet, as a book opens from the library and a saga from Découvrir:
        // the same corners on an author. Its own stack, so a saga pushes inside it.
        .sheet(item: $openAuthor) { opened in
            NavigationStack {
                AuthorView(key: opened.key, name: opened.name, isSheet: true)
            }
        }
    }

    private func row(_ author: FollowedAuthor) -> some View {
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

    /// The authors cut where the letter they are filed under changes. The
    /// server already hands them over in that order, "#" last.
    private var letters: [(letter: String, authors: [FollowedAuthor])] {
        var sections: [(letter: String, authors: [FollowedAuthor])] = []
        for author in viewModel.authors {
            if sections.last?.letter == author.indexLetter {
                sections[sections.count - 1].authors.append(author)
            } else {
                sections.append((author.indexLetter, [author]))
            }
        }
        return sections
    }

    /// The two orders, as the Books and Series shelves offer their two views.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            ForEach(AuthorListOrder.allCases) { item in
                Button {
                    Task { await viewModel.show(item) }
                } label: {
                    Label(item.label, systemImage: item.icon)
                }
                .labelStyle(.iconOnly)
                .tint(viewModel.order == item ? .accentColor : .primary)
                .accessibilityIdentifier("authors-order-\(item.rawValue)")
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
