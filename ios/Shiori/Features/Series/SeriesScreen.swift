import SwiftUI

/// One saga, connected: `SeriesViewModel` loads it and acts on it, this screen
/// holds the toolbar, the sheets and the alerts, and `SeriesPage` draws it.
///
/// Removing the saga removes every volume of it the reader holds, which the
/// confirmation says in so many words.
struct SeriesScreen: View {
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(\.detailClosing) private var closing

    /// Pops the screen, closes its sheet, or empties the detail column it
    /// fills on an unfolded iPhone Duo.
    private func dismiss() { closing.close(dismissPresentation) }

    @State private var viewModel: SeriesViewModel
    @State private var isEditingGenre = false
    @State private var isRating = false
    /// The sheet picking the saga this one, a duplicate, is folded into.
    @State private var isMerging = false
    /// The saga was folded into another: its screen closes with the sheet.
    @State private var merged = false
    /// The owned volume the reader tapped, opened over the list.
    @State private var selectedBook: Book?
    /// The sheet asking how many volumes a saga nobody catalogued has.
    @State private var isDeclaringVolumeCount = false
    /// The announced volume whose page is open, as Découvrir opens it.
    @State private var announced: DiscoveredVolume?
    /// The author whose page the hero's author line opened.
    @State private var openAuthor: AuthorDestination?
    /// Whether the saga is laid out as two pages, on an unfolded iPhone Duo:
    /// a volume then opens on the second page rather than over the list.
    @State private var isSpread = false

    /// - Parameters:
    ///   - language: the edition the reader came from. A saga held in two
    ///     languages shares one `seriesId`; nil where the caller knows no
    ///     edition, and every edition shows.
    ///   - proposal: the saga as an author's page names it, for a saga the
    ///     reader holds nothing of: the server catalogues it from this.
    ///   - friend: the friend whose shelf the saga was opened from.
    init(
        seriesId: String,
        language: BookLanguage? = nil,
        proposal: SeriesProposal? = nil,
        friend: SeriesFriend? = nil,
        client: SeriesClient = .live
    ) {
        _viewModel = State(initialValue: SeriesViewModel(
            seriesId: seriesId,
            language: language,
            proposal: proposal,
            friend: friend,
            client: client
        ))
    }

    var body: some View {
        // On an unfolded iPhone Duo the volumes keep the first page and the
        // one touched opens on the second, which shows the volume announced
        // next — or the one being read — until the reader picks another.
        TwoPages {
            page
        } second: {
            NavigationStack { volumePage }
                .environment(\.detailClosing, .pushed)
        } single: {
            page
        }
        .onPreferenceChange(TwoPagesShownKey.self) { isSpread = $0 }
        // In the corner even when the catalogue is missing: what a reader thinks
        // of a saga does not wait on the world having described it.
        .toolbar {
            if closing.showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            if viewModel.friend == nil { ownerToolbar }
        }
        // What the AI is writing, said in the bar: the page under it stays
        // readable and every action at hand.
        .generatingInBar(viewModel.generating)
        // The stars commit on the tap and the control cannot show the call
        // itself, so the wait is made visible by a scrim.
        .overlay {
            if viewModel.isSaving {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        .disabled(viewModel.isSaving)
        .pushesDetail(item: pushedUnlessSpread($selectedBook)) { book in
            volumeScreen(book)
        }
        .pushesDetail(item: $openAuthor) { author in
            AuthorScreen(key: author.key, name: author.name)
        }
        .sheet(isPresented: $isRating) {
            RatingPromptSheet(
                subject: .series,
                current: viewModel.opinion?.rating,
                onRemove: {
                    isRating = false
                    Task { await viewModel.rate(0) }
                },
                onRate: { stars in
                    isRating = false
                    Task { await viewModel.rate(stars) }
                }
            )
        }
        .sheet(isPresented: $isMerging, onDismiss: { if merged { dismiss() } }) {
            MergeSeriesSheet(
                seriesId: viewModel.seriesId,
                seriesName: viewModel.name,
                isAudio: viewModel.seriesId.hasSuffix("--audio"),
                author: viewModel.series?.author ?? viewModel.owned.first?.authors.first,
                ownedCount: viewModel.owned.count,
                loadCandidates: viewModel.mergeCandidates
            ) { target in
                let failure = await viewModel.merge(into: target)
                if failure == nil { merged = true }
                return failure
            }
        }
        .sheet(isPresented: $isDeclaringVolumeCount) {
            VolumeCountSheet(
                seriesName: viewModel.name,
                count: viewModel.opinion?.volumeCount ?? max(viewModel.highestOwnedVolume, 1)
            ) { count in
                await viewModel.declareVolumeCount(count)
            }
        }
        .sheet(isPresented: $isEditingGenre) {
            if let volume = viewModel.owned.first {
                // Saved on one volume; the server carries it to every volume.
                GenreEditSheet(book: volume, loadSubgenres: viewModel.subgenres) { correction in
                    await viewModel.correctGenre(correction)
                }
            }
        }
        // Added from its page, the volume takes its row back as the reader's.
        .pushesDetail(item: pushedUnlessSpread($announced), onClose: { _ in Task { await viewModel.load() } }) { volume in
            if let saga = viewModel.announcedSaga {
                AnnouncedVolumeScreen(saga: saga, volume: volume, linksToSaga: false)
            }
        }
        .task {
            await viewModel.load()
            await viewModel.buildCatalogueIfAwaiting()
        }
        .task { await viewModel.loadReleases() }
    }

    /// A volume of the saga: the reader's own, or a friend's as their shelf
    /// opens it.
    @ViewBuilder
    private func volumeScreen(_ book: Book) -> some View {
        if let friend = viewModel.friend {
            FriendBookScreen(friendId: friend.id, bookId: book.id, friendName: friend.name)
        } else {
            BookScreen(
                bookId: book.id,
                onChanged: { _ in Task { await viewModel.load() } },
                onDeleted: { _ in Task { await viewModel.load() } }
            )
        }
    }

    /// The second page of the spread: the volume touched, else the one
    /// announced next, else the one being read or next on the pile.
    @ViewBuilder
    private var volumePage: some View {
        if let book = selectedBook {
            volumeScreen(book).id(book.id)
        } else if let volume = announced ?? viewModel.releases?.next, let saga = viewModel.announcedSaga {
            AnnouncedVolumeScreen(saga: saga, volume: volume, linksToSaga: false).id(volume.id)
        } else if let book = restingVolume {
            volumeScreen(book).id(book.id)
        } else {
            ContentUnavailableView(
                "Aucun tome ouvert",
                systemImage: "books.vertical",
                description: Text("Le tome touché s'ouvre sur cette page.")
            )
        }
    }

    /// The volume the second page rests on: the one being read, else the
    /// first on the pile.
    private var restingVolume: Book? {
        viewModel.owned.first { $0.status == .reading } ?? viewModel.owned.first { $0.status == .toRead }
    }

    /// A detail pushed over the saga on one page; on two it opens on the
    /// second page instead, and nothing is pushed.
    private func pushedUnlessSpread<T>(_ binding: Binding<T?>) -> Binding<T?> {
        Binding(
            get: { isSpread ? nil : binding.wrappedValue },
            set: { binding.wrappedValue = $0 }
        )
    }

    private var page: some View {
        SeriesPage(
            series: viewModel.series,
            owned: viewModel.owned,
            opinion: viewModel.opinion,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            language: viewModel.language,
            friend: viewModel.friend,
            isFollowed: viewModel.isFollowed,
            addingTitle: viewModel.addingTitle,
            releases: viewModel.releases,
            takenFormat: viewModel.takenFormat,
            announcedVolume: viewModel.announcedVolume
        ) { action in
            switch action {
            case let .openBook(book):
                announced = nil
                selectedBook = book
            case .rate: isRating = true
            case .editGenre: isEditingGenre = true
            case let .setFollowed(followed): await viewModel.setFollowed(followed)
            case let .openAuthor(author): openAuthor = author
            case let .openAnnounced(volume):
                selectedBook = nil
                announced = volume
            case let .add(volume, author, format, status):
                await viewModel.add(volume, author: author, as: format, status: status)
            case .retry: await viewModel.load()
            case .declareVolumeCount: isDeclaringVolumeCount = true
            }
        }
    }

    /// What the reader can do with a saga of their own: the heart, the saga
    /// taken up from its first volume, and the menu. None of it on a friend's
    /// shelf.
    @ToolbarContentBuilder
    private var ownerToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            AsyncToolbarButton(
                title: viewModel.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                systemImage: viewModel.isFavorite ? "heart.fill" : "heart"
            ) {
                await viewModel.setFavorite(!viewModel.isFavorite)
            }
            .tint(viewModel.isFavorite ? .red : nil)
            .accessibilityIdentifier("series-favorite")
        }
        // A saga the reader holds nothing of — offered on an author's page or
        // by Découvrir — joins their sagas with its first volume, on the pile.
        if viewModel.owned.isEmpty, let series = viewModel.series, let first = viewModel.firstVolume {
            ToolbarItem(placement: .primaryAction) {
                AsyncToolbarButton(title: "Ajouter à mes séries", systemImage: "plus") {
                    await viewModel.add(first, author: series.author)
                }
                .disabled(viewModel.addingTitle != nil)
                .accessibilityIdentifier("series-add")
            }
        }
        if !viewModel.owned.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                SeriesActionsMenu(
                    isProvisional: viewModel.series?.isProvisional == true,
                    ownedCount: viewModel.owned.count
                ) { action in
                    switch action {
                    case .declareVolumeCount: isDeclaringVolumeCount = true
                    case .merge: isMerging = true
                    case .delete:
                        Task { if await viewModel.delete() { dismiss() } }
                    }
                }
            }
        }
    }
}

/// The friend whose shelf a saga screen was opened from.
struct SeriesFriend: Hashable, Sendable {
    let id: String
    let name: String
}

/// What opens a saga screen: the saga and, when the caller stands in one, the
/// edition. Two rows of the Series tab share a saga and differ by language, so
/// the language is part of the identity, as it is on `FollowedSeries`.
struct SeriesDestination: Identifiable, Hashable {
    let seriesId: String
    let language: BookLanguage?
    var proposal: SeriesProposal? = nil

    var id: String { "\(seriesId)|\(language?.rawValue ?? "")" }
}

/// A saga the reader holds nothing of, as whoever offered it names it: what its
/// catalogue is asked for with, since no volume of theirs can say.
struct SeriesProposal: Hashable, Sendable {
    let name: String
    let author: String
}
