import SwiftUI

/// One saga, laid out like the book screen: a main section with where the
/// reader stands as a ring, what the saga is, its genre and subgenres, the
/// reader's rating of it and the dates of their reading; then every volume in
/// the order of the cycle, drawn as the library draws its rows.
///
/// The owned volumes are the reader's own books and open as they do from the
/// library; the missing ones are proposals, dimmed, with a button to add them.
/// Nothing enters the library until the reader adds it.
///
/// Removing the saga removes every volume of it the reader holds, which the
/// confirmation says in so many words.
///
/// Opened from a friend's shelf, the same catalogue reads as theirs: the ring,
/// the dates, the stars and the volumes held are the friend's, read-only, and
/// a volume of theirs opens as their book does.
struct SeriesView: View {
    let seriesId: String
    /// The edition the reader came from. The catalogue is keyed by name and
    /// author, so a saga held in two languages shares one `seriesId` and the
    /// library answers with both editions' books: without this, the French row
    /// of the Series tab opened on the English covers. Nil where the caller
    /// knows no edition — the dashboard's series card — and every edition shows.
    var language: BookLanguage? = nil
    /// Opened as a sheet — from Découvrir, as a book opens from the library —
    /// rather than pushed: a close button in the corner.
    var isSheet = false
    /// The saga as an author's page names it, for a saga the reader holds
    /// nothing of: the server catalogues it from this on the first opening.
    var proposal: SeriesProposal? = nil
    /// The friend whose shelf the saga was opened from: where it stands is
    /// theirs, and nothing on the screen changes the reader's library.
    var friend: SeriesFriend? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var series: BookSeries?
    /// Every volume of the saga the reader holds — the friend, on their
    /// shelf — numbered or not: what the
    /// genre and the dates are read off, and what the genre is corrected on.
    @State private var owned: [Book] = []
    @State private var isEditingGenre = false
    @State private var opinion: SeriesOpinion?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addingTitle: String?
    /// A rating, a heart or the removal is on its way to the server.
    @State private var isSaving = false
    @State private var confirmDelete = false
    /// The sheet picking the saga this one, a duplicate, is folded into.
    @State private var isMerging = false
    /// The saga was folded into another: its screen closes with the sheet.
    @State private var merged = false
    @State private var isRating = false
    /// The refresh came back with nothing: the catalogue on screen is the old one.
    @State private var refreshFailed = false
    @State private var isRefreshing = false
    /// The owned volume the reader tapped, opened over the list.
    @State private var selectedBook: Book?
    /// The sheet asking how many volumes the saga has, for a saga nobody has
    /// catalogued.
    @State private var isDeclaringVolumeCount = false
    /// What Découvrir found of the saga in the edition opened: the next volume
    /// announced the reader lacks. Last opening's at once,
    /// brought up to date underneath.
    @State private var releases: SagaReleases?
    /// The announced volume whose page is open, as Découvrir opens it.
    @State private var announced: DiscoveredVolume?

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        Group {
            if isLoading && series == nil && owned.isEmpty {
                // Labelled because the first opening of a saga an import named
                // is where the server builds its catalogue, which takes a while.
                ProgressView("Chargement du catalogue…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let series {
                catalogue(series)
            } else {
                // The world could not describe the saga: the reader can count
                // its volumes themselves and have their screen drawn from that.
                EmptyStateView(
                    systemImage: "square.stack.3d.up.slash",
                    title: "Série non cataloguée",
                    verbatim: errorMessage ?? String(localized: "Shiori n'a pas réussi à constituer le catalogue de cette série. Réessayez plus tard, ou scannez la couverture d'un de ses tomes."),
                    primary: .init("Réessayer", systemImage: "arrow.clockwise") { await load() },
                    secondary: owned.isEmpty || friend != nil
                        ? nil
                        : .init("Indiquer le nombre de tomes", systemImage: "number") {
                            isDeclaringVolumeCount = true
                        }
                )
            }
        }
        .navigationTitle(series?.name ?? "Série")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(FriendSubtitle(name: friend?.name))
        // In the corner even when the catalogue is missing: what a reader thinks
        // of a saga does not wait on the world having described it.
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            if friend == nil { ownerToolbar }
        }
        .alert("Catalogue non mis à jour", isPresented: $refreshFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Shiori n'a pas réussi à reconstituer le catalogue de cette série. L'ancien est conservé ; réessayez plus tard.")
        }
        // The stars commit on the tap and the control cannot show the call
        // itself, so the wait is made visible by a scrim, as on the book sheet.
        // A refresh is one grounded model call and takes a while, so its scrim
        // says what it is waiting on.
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    if isRefreshing {
                        ProgressView("Mise à jour du catalogue…")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        .disabled(isSaving)
        .sheet(item: $selectedBook) { book in
            if let friend {
                // The friend's volume, as their shelf opens it.
                NavigationStack {
                    FriendBookView(friendId: friend.id, bookId: book.id, friendName: friend.name)
                }
            } else {
                BookView(
                    bookId: book.id,
                    onChanged: { _ in Task { await load() } },
                    onDeleted: { _ in Task { await load() } }
                )
            }
        }
        .sheet(isPresented: $isRating) {
            RatingPromptView(
                subject: .series,
                current: opinion?.rating,
                onRemove: {
                    isRating = false
                    Task { await rate(0) }
                },
                onRate: { stars in
                    isRating = false
                    Task { await rate(stars) }
                }
            )
        }
        .sheet(isPresented: $isMerging, onDismiss: { if merged { dismiss() } }) {
            MergeSeriesSheet(
                seriesId: seriesId,
                seriesName: series?.name ?? owned.first?.series?.name ?? "",
                isAudio: seriesId.hasSuffix("--audio"),
                author: series?.author ?? owned.first?.authors.first,
                ownedCount: owned.count
            ) { target in
                await merge(into: target)
            }
        }
        .sheet(isPresented: $isDeclaringVolumeCount) {
            VolumeCountSheet(
                seriesName: series?.name ?? owned.first?.series?.name ?? "",
                count: opinion?.volumeCount ?? max(highestOwnedVolume, 1)
            ) { count in
                do {
                    opinion = try await SeriesAPI.declareVolumeCount(seriesId: seriesId, count: count)
                    // Read again on purpose: the provisional catalogue the
                    // count gives rise to is drawn by the server, and the
                    // mutation answers with the opinion alone.
                    await load()
                    return nil
                } catch {
                    return reportError(error)
                }
            }
        }
        .sheet(isPresented: $isEditingGenre) {
            if let volume = owned.first {
                // Saved on one volume; the server carries what was edited to
                // every volume of the saga, so the whole shelf follows. The
                // answer says what the saga now carries, and every volume on
                // screen takes it, field by field as the server does: a genre
                // changed alone leaves each volume's subgenres its own.
                GenreEditSheet(book: volume) { correction in
                    do {
                        let updated = try await BookAPI.update(id: volume.id, correction: correction)
                        owned = owned.map { book in
                            var book = book
                            if correction.genre != nil { book.genre = updated.genre }
                            if correction.subgenres != nil { book.subgenres = updated.subgenres }
                            return book
                        }
                        return nil
                    } catch {
                        return reportError(error)
                    }
                }
            }
        }
        // Added from its page, the volume takes its row back as the reader's.
        .sheet(item: $announced, onDismiss: { Task { await load() } }) { volume in
            if let saga = announcedSaga {
                NavigationStack {
                    AnnouncedVolumeView(saga: saga, volume: volume, linksToSaga: false)
                }
            }
        }
        .task { await load() }
        .task { await loadReleases() }
    }

    /// What the reader can do with a saga of their own: the heart, the
    /// saga taken up from its first volume, and the menu. None of it on a
    /// friend's shelf.
    @ToolbarContentBuilder
    private var ownerToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            AsyncToolbarButton(
                title: isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                systemImage: isFavorite ? "heart.fill" : "heart"
            ) {
                await setFavorite(!isFavorite)
            }
            .tint(isFavorite ? .red : nil)
            .accessibilityIdentifier("series-favorite")
        }
        // A saga the reader holds nothing of — offered on an author's page
        // or by Découvrir — joins their sagas with its first volume, on the
        // pile.
        if owned.isEmpty, let series, let first = firstVolume(of: series) {
            ToolbarItem(placement: .primaryAction) {
                AsyncToolbarButton(title: "Ajouter à mes séries", systemImage: "plus") {
                    await add(first, author: series.author)
                }
                .disabled(addingTitle != nil)
                .accessibilityIdentifier("series-add")
            }
        }
        if !owned.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Only over a catalogue: with none, the screen's own
                    // retry button already asks the world about the saga.
                    if series != nil {
                        Button("Mettre à jour", systemImage: "arrow.clockwise") {
                            Task { await refreshCatalogue() }
                        }
                        .accessibilityIdentifier("series-refresh")
                    }
                    // The count is the reader's own: they can correct it
                    // for as long as it is what the screen is drawn from.
                    if series?.isProvisional == true {
                        Button("Nombre de tomes", systemImage: "number") {
                            isDeclaringVolumeCount = true
                        }
                        .accessibilityIdentifier("series-volume-count")
                    }
                    // Only the saga is set aside: its volumes keep their
                    // own statuses in the library.
                    if isFollowed {
                        Button("Ne plus suivre", systemImage: "bell.slash") {
                            Task { await setFollowed(false) }
                        }
                        .accessibilityIdentifier("series-unfollow")
                    } else {
                        Button("Suivre", systemImage: "bell") {
                            Task { await setFollowed(true) }
                        }
                        .accessibilityIdentifier("series-follow")
                    }
                    // A scan and an import often name one saga twice: the
                    // reader keeps one, and this one's volumes move there.
                    Button("Fusionner avec…", systemImage: "arrow.triangle.merge") {
                        isMerging = true
                    }
                    .accessibilityIdentifier("series-merge")
                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                        confirmDelete = true
                    }
                    .accessibilityIdentifier("series-delete")
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(Text("Plus d'actions"))
                .accessibilityIdentifier("series-menu")
                // Attached to the menu, as on the book sheet: the dialog
                // rises from the button that asked rather than the screen.
                .confirmationDialog(
                    "Supprimer la série ?",
                    isPresented: $confirmDelete,
                    titleVisibility: .visible
                ) {
                    Button("Supprimer", role: .destructive) { Task { await deleteSeries() } }
                        .accessibilityIdentifier("choice-delete-series")
                    Button("Annuler", role: .cancel) {}
                } message: {
                    Text("Les \(owned.count) livres de cette série dans votre bibliothèque seront supprimés avec elle, ainsi que votre note. Cette action est définitive.")
                }
            }
        }
    }

    private func catalogue(_ series: BookSeries) -> some View {
        List {
            mainSection(series)
            if friend == nil, let releases {
                SagaReleasesSection(
                    releases: releases,
                    author: series.author,
                    held: heldNumbers,
                    isAudio: series.isAudio,
                    open: { announced = $0 }
                )
            }
            volumes("Tomes", volumes: series.spine, author: series.author, footer: nil)
            if !series.relatedWorks.isEmpty {
                volumes(
                    "Récits annexes",
                    volumes: series.relatedWorks,
                    author: series.author,
                    footer: "Préquelles, nouvelles et hors-séries, en dehors de la numérotation."
                )
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
    }

    /// What the saga is and where the reader stands with it, in one section as
    /// on the book screen: the ring and the name, the summary, the genre, the
    /// rating and the dates.
    private func mainSection(_ series: BookSeries) -> some View {
        let standing = progress(series)
        return Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    SeriesRing(read: standing.read, total: standing.published)
                        .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 3) {
                        SagaName(name: series.name, isAudio: series.isAudio)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .copyable(series.name)
                        Text(series.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .copyable(series.author)
                        Text("\(series.spine.count) tome(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        if series.isProvisional {
                            Text("d'après votre décompte")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                // In the corner, as on the Series tab row: the crossed-out
                // bell says the saga is set aside.
                .overlay(alignment: .topTrailing) {
                    if friend == nil, !isFollowed {
                        SeriesStateLabel(state: .unfollowed)
                            .accessibilityIdentifier("series-unfollowed")
                    }
                }
                if let description = series.description {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .copyable(description)
                }
            }
            .padding(.vertical, 6)

            if !owned.isEmpty { genreRow }

            if let friend {
                friendOpinion(friend)
            } else {
                ownRating
            }

            if let started = startedAt {
                LabeledInfoRow(
                    title: "Commencée le",
                    value: started.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar.badge.plus"
                )
            }
            if let added = addedAt {
                LabeledInfoRow(
                    title: "Ajoutée le",
                    value: added.formatted(date: .abbreviated, time: .omitted),
                    icon: "tray.and.arrow.down"
                )
            }
            if let finished = finishedAt {
                LabeledInfoRow(
                    title: "Terminée le",
                    value: finished.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar.badge.checkmark"
                )
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if series.isProvisional {
                    Text("Catalogue provisoire, dessiné d'après le nombre de tomes que vous avez indiqué. « Mettre à jour » demande le vrai.")
                }
                if !owned.isEmpty, friend == nil {
                    Text("Le genre et les sous-genres s'appliquent à tous les tomes de la série dans votre bibliothèque.")
                }
            }
        }
    }

    @ViewBuilder
    private var ownRating: some View {
        // The saga's own rating, not the average of its volumes: a cycle
        // can be worth more than its books — the shape only shows at the
        // end — or rather less, when three good ones are followed by four
        // that should not exist.
        // Read-only stars and a prompt behind them, as on the book screen.
        if let rating = opinion?.rating {
            Button { isRating = true } label: {
                Label {
                    LabeledContent("Note") { StarRatingView(rating: rating) }
                } icon: {
                    Image(systemName: "star").foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
            .accessibilityIdentifier("series-rating")
        } else {
            Button { isRating = true } label: {
                Label("Noter cette série", systemImage: "star")
            }
            .accessibilityIdentifier("series-rate")
        }
    }

    /// The friend's stars and heart for the saga, read-only, under their name:
    /// nothing to prompt when they gave neither.
    @ViewBuilder
    private func friendOpinion(_ friend: SeriesFriend) -> some View {
        if let rating = opinion?.rating {
            Label {
                LabeledContent("Note de \(friend.name)") { StarRatingView(rating: rating) }
            } icon: {
                Image(systemName: "star").foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("series-friend-rating")
        }
        if isFavorite {
            Label {
                Text("Coup de cœur")
            } icon: {
                Image(systemName: "heart.fill").foregroundStyle(.red)
            }
            .accessibilityIdentifier("series-friend-favorite")
        }
    }

    /// The highest number among the volumes the reader holds: where the count
    /// sheet starts, since the saga has at least that many.
    private var highestOwnedVolume: Int { owned.compactMap(\.series?.volume).max() ?? 0 }

    /// The genre and its subgenres on one tappable row, as on the book screen
    /// — read-only on a friend's shelf, where it is theirs to correct.
    @ViewBuilder
    private var genreRow: some View {
        if friend == nil {
            Button { isEditingGenre = true } label: { genreLabel(editable: true) }
                .tint(.primary)
                .accessibilityIdentifier("series-genre")
        } else {
            genreLabel(editable: false)
                .accessibilityIdentifier("series-genre")
        }
    }

    private func genreLabel(editable: Bool) -> some View {
        let volume = owned.first
        return Label {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Genre") {
                    HStack(spacing: 4) {
                        if let genre = volume?.genre {
                            genre.image.imageScale(.small)
                        }
                        Text(volume?.genre?.label ?? String(localized: "Non renseigné"))
                            .multilineTextAlignment(.trailing)
                        if editable {
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                    }
                    .foregroundStyle(editable ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                if let subgenres = volume?.subgenres, !subgenres.isEmpty {
                    TagList(tags: subgenres, systemImage: "tag")
                }
            }
        } icon: {
            Image(systemName: "books.vertical").foregroundStyle(.secondary)
        }
    }

    /// One block of volumes, a row each, in catalogue order.
    private func volumes(
        _ title: LocalizedStringKey,
        volumes: [Volume],
        author: String,
        footer: LocalizedStringKey?
    ) -> some View {
        Section {
            ForEach(volumes) { volume in
                volumeRow(volume, author: author)
            }
        } header: {
            Text(title)
        } footer: {
            if let footer { Text(footer) }
        }
    }

    /// One volume. Owned, it is the reader's own books, drawn as the library
    /// draws them and opened as the library opens them — a row per part of a
    /// novel sold in two; missing, it is dimmed and offers to be added; not out
    /// yet, it says when.
    @ViewBuilder
    private func volumeRow(_ volume: Volume, author: String) -> some View {
        let label = volume.number.map { "\(volume.kind.label) \($0)" } ?? volume.kind.label
        // Matched by kind and number, or by title for an unnumbered related
        // work: a volume just added from here takes its row back on reload.
        let books = owned.filter(volume.matches)
        if books.isEmpty {
            missingRow(volume, label: label, author: author)
        }
        ForEach(books) { book in
            Button { selectedBook = book } label: {
                BookRow(
                    title: book.title,
                    authorLine: book.authorLine,
                    cover: book,
                    status: book.status,
                    rating: book.shownRating,
                    ratingIsInherited: book.ratingIsInherited,
                    volumeLabel: label,
                    publishedIn: volume.publishedIn,
                    statusTag: book.status,
                    subgenre: nil,
                    isFavorite: book.favorite,
                    isHidden: book.hidden
                )
            }
            .tint(.primary)
            .accessibilityIdentifier("series-volume-owned")
        }
    }

    /// A volume the reader does not hold, in the library row's layout: the
    /// placeholder cover dimmed — whole for a volume announced, which opens on
    /// its page — with the headphones of a recording, the number and title, when it came out, and
    /// what can be done about it.
    private func missingRow(_ volume: Volume, label: String, author: String) -> some View {
        // The edition opened names it and dates it when the release watch
        // found it there: the French volume 5 comes out on its own day.
        let release = language.flatMap { volume.release(in: $0) }
        let title = release?.title ?? volume.title
        let forthcoming = volume.isForthcoming(asOf: currentYear, in: language, datedUpTo: datedUpTo)
        let page = forthcoming ? announcedVolume(volume) : nil
        return HStack(alignment: .top, spacing: 12) {
            // An announced volume opens on its page: its cover is drawn whole.
            BookCover(book: Book(
                id: volume.id,
                title: title,
                authors: [author],
                format: series?.isAudio == true ? .audiobook : .book,
                coverURL: release?.coverURL,
                status: .toRead
            ), coverOpacity: page == nil ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Group {
                    if forthcoming, let date = release?.date {
                        Text(ReleaseDateText.coming(date))
                            .foregroundStyle(.orange)
                            .fontWeight(.medium)
                    } else if forthcoming, let year = volume.publishedIn, year > currentYear {
                        Text("à paraître en \(String(year))")
                    } else if forthcoming {
                        // Out in another language, not yet in this one.
                        Text("Pas encore paru")
                    } else if let year = release.map({ String($0.date.prefix(4)) }) ?? volume.publishedIn.map(String.init) {
                        Text(verbatim: year)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            action(volume, author: author)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // Announced in the edition opened, it opens on its page as on Découvrir.
        .onTapGesture { if let page { announced = page } }
        .accessibilityAddTraits(page == nil ? [] : .isButton)
    }

    /// The page of a volume the release watch announced in the edition opened:
    /// what Découvrir knows of it when it is the next one, with its Audible
    /// link, else what the catalogue keeps of the announcement. Nil for a
    /// volume the watch never found in that edition — the server describes
    /// only those.
    private func announcedVolume(_ volume: Volume) -> DiscoveredVolume? {
        guard volume.kind == .main, let number = volume.number,
              let release = language.flatMap({ volume.release(in: $0) })
        else { return nil }
        if let next = releases?.next, next.number == number { return next }
        return DiscoveredVolume(
            number: number,
            title: release.title,
            date: release.date,
            isbn13: nil,
            coverURL: release.coverURL
        )
    }

    /// The saga as the announced volume's page reads it: the edition opened.
    private var announcedSaga: SagaDiscovery? {
        guard let series, let language else { return nil }
        let followed = FollowedSeries(
            seriesId: seriesId,
            name: series.name,
            isAudio: series.isAudio,
            author: series.author,
            language: language,
            state: nil,
            genre: owned.first?.genre,
            ownedCount: owned.count
        )
        return SagaDiscovery(series: followed, releases: releases ?? SagaReleases(watched: true, next: nil))
    }

    /// What can be done with a volume the reader does not hold: add it, or
    /// nothing yet when it is not out. On a friend's shelf the volume is one
    /// they lack, and nothing is offered.
    @ViewBuilder
    private func action(_ volume: Volume, author: String) -> some View {
        if volume.isForthcoming(asOf: currentYear, in: language, datedUpTo: datedUpTo) {
            // Orange once the edition has a date, as the date beside it is.
            let dated = language.flatMap { volume.release(in: $0) } != nil
            Image(systemName: "clock")
                .foregroundStyle(dated ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                .accessibilityLabel(Text("Pas encore paru"))
        } else if friend != nil {
            EmptyView()
        } else if addingTitle == volume.title {
            ProgressView().controlSize(.small)
        } else {
            Menu {
                ForEach(takenFormat.takenAs, id: \.self) { format in
                    Section(format.label) {
                        Button("Ajouter à ma pile", systemImage: "bookmark.fill") {
                            Task { await add(volume, author: author, as: format) }
                        }
                        .accessibilityIdentifier("series-volume-add-pile-\(format.rawValue)")
                        Button(
                            format == .audiobook ? "Je l'ai déjà écouté" : "Je l'ai déjà lu",
                            systemImage: "checkmark"
                        ) {
                            Task { await add(volume, author: author, as: format, status: .read) }
                        }
                        .accessibilityIdentifier("series-volume-add-read-\(format.rawValue)")
                    }
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Ajouter « \(volume.title) » à ma bibliothèque"))
            .accessibilityIdentifier("series-volume-add")
        }
    }

    /// What the saga is read as: the format of the volumes held — a manga
    /// stays a manga — else a recording for a saga heard, a book otherwise.
    /// A volume is offered in that format's print form and as a recording,
    /// as a friend's book is.
    private var takenFormat: BookFormat {
        owned.first?.format ?? (series?.isAudio == true ? .audiobook : .book)
    }

    /// How far the edition opened was dated: past it, a volume out elsewhere
    /// is not out in this language yet.
    private var datedUpTo: Int? { series?.spine.datedUpTo(in: language) }

    /// The volume a saga is started with: the first of the spine already out.
    private func firstVolume(of series: BookSeries) -> Volume? {
        series.spine.first { !$0.isForthcoming(asOf: currentYear, in: language, datedUpTo: datedUpTo) }
    }

    // MARK: - Dates

    /// When the reader opened the first of their volumes.
    private var startedAt: Date? { owned.compactMap(\.startedAt).min() }
    /// When the first of their volumes entered the library.
    private var addedAt: Date? { owned.compactMap(\.addedAt).min() }
    /// When they finished the last of their main volumes — only once every one
    /// they hold is read: a saga with a volume still open is not finished. The
    /// related works are left out, as the server leaves them out of the saga's
    /// state: an unread novella does not hold a finished saga open.
    private var finishedAt: Date? {
        let main = owned.filter { $0.series?.kind == .main }
        guard !main.isEmpty, main.allSatisfy({ $0.status == .read }) else { return nil }
        return main.compactMap(\.finishedAt).max()
    }

    /// How far the reader is along the spine, in the edition opened: the volumes
    /// out, and the ones announced to the day — the next one is then awaited,
    /// and the ring says 4 of 5. A volume announced for a month or a year is
    /// left out: it would make a finished saga look unfinished for years.
    private func progress(_ series: BookSeries) -> (read: Int, published: Int) {
        let published = series.spine.filter { $0.counts(asOf: currentYear, in: language, datedUpTo: datedUpTo) }
        // Read once any of its books is, as the server counts it: a part read
        // with the other still ahead, or one format of two, reads the volume.
        let read = published.filter { volume in
            owned.contains { volume.matches($0) && $0.status == .read }
        }
        return (read.count, published.count)
    }

    /// One request for the whole screen: assigned one by one, the catalogue
    /// drew first with placeholder covers and no genre row, and the reader's own
    /// volumes filled it in a moment later. The owned volumes come from the saga
    /// alone — reading the whole library to keep a handful of rows signed every
    /// cover in it, and the screen slowed down as the library grew.
    private func load() async {
        isLoading = true
        if let friend {
            await loadFriendShelf(friend)
            isLoading = false
            return
        }
        do {
            let screen = try await SeriesAPI.screen(id: seriesId, language: language, proposal: proposal)
            series = screen.series
            opinion = screen.opinion
            owned = screen.owned
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    /// The catalogue, with the friend's volumes, stars and heart in place of
    /// the reader's own.
    private func loadFriendShelf(_ friend: SeriesFriend) async {
        do {
            let screen = try await FriendsAPI.sagaScreen(
                friendId: friend.id,
                seriesId: seriesId,
                language: language
            )
            series = screen.series
            owned = screen.saga?.volumes ?? []
            opinion = screen.saga.map {
                SeriesOpinion(seriesId: seriesId, rating: $0.rating, favorite: $0.favorite)
            }
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// What Découvrir found of the saga, for an edition the reader opened —
    /// looked up on the spot when nobody ever did. The dashboard's card names
    /// no edition, and has nothing to show here.
    private func loadReleases() async {
        // The section speaks of the volumes the reader lacks: not drawn on a
        // friend's shelf.
        guard friend == nil, let language else { return }
        let key = "\(seriesId)|\(language.rawValue)"
        if releases == nil { releases = SagaReleasesCache.entries[key] }
        do {
            var fetched = try await DiscoverAPI.sagaReleases(seriesId: seriesId, language: language)
            withAnimation(releases == nil ? nil : .smooth) { releases = fetched }
            // Nobody ever looked the saga up in this edition: it is looked up
            // now, and the section slides in when the web has answered.
            if !fetched.watched {
                fetched = try await DiscoverAPI.lookUpSaga(seriesId: seriesId, language: language)
                withAnimation(.smooth) { releases = fetched }
            }
            SagaReleasesCache.entries[key] = fetched
        } catch {
            // The section is a bonus on this screen: without it the saga still
            // reads, so the failure is reported rather than shown.
            _ = reportError(error)
        }
    }

    /// The numbers of the main volumes the reader holds.
    private var heldNumbers: Set<Int> {
        Set(owned.compactMap { $0.series?.kind == .main ? $0.series?.volume : nil })
    }

    private var isFavorite: Bool { opinion?.favorite == true }

    // The server answers with the opinion as it now stands, so the screen takes
    // that rather than guessing: a rating taken back may leave a heart behind,
    // and an opinion emptied of both is erased server-side.
    private func rate(_ stars: Int) async {
        isSaving = true
        defer { isSaving = false }
        do {
            opinion =
                stars == 0
                ? try await SeriesAPI.removeRating(seriesId: seriesId)
                : try await SeriesAPI.rate(seriesId: seriesId, stars: stars)
        } catch {
            errorMessage = reportError(error)
        }
    }

    private var isFollowed: Bool { opinion?.follows(language) ?? true }

    private func setFollowed(_ followed: Bool) async {
        isSaving = true
        defer { isSaving = false }
        do {
            // Only the edition the reader came from: the French row set
            // aside says nothing of the English one.
            opinion = try await SeriesAPI.setFollowed(
                seriesId: seriesId,
                followed: followed,
                language: language
            )
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func setFavorite(_ favorite: Bool) async {
        isSaving = true
        defer { isSaving = false }
        do {
            opinion = try await SeriesAPI.setFavorite(seriesId: seriesId, favorite: favorite)
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Asks the world about the saga again. The fresh catalogue replaces the one
    /// on screen; when it could not be rebuilt the old one stays, and the
    /// reader is told rather than left wondering whether anything happened.
    private func refreshCatalogue() async {
        isSaving = true
        isRefreshing = true
        defer {
            isSaving = false
            isRefreshing = false
        }
        do {
            if let refreshed = try await SeriesAPI.refresh(seriesId: seriesId, language: language) {
                series = refreshed
            } else {
                refreshFailed = true
            }
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func deleteSeries() async {
        isSaving = true
        defer { isSaving = false }
        do {
            // The edition this screen shows, and no other: the French row of a
            // saga held in two languages must not take the English books with it.
            try await SeriesAPI.delete(seriesId: seriesId, language: language)
            dismiss()
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Folds this saga into the one the reader picked. The screen leaves once
    /// the sheet has closed: the saga is gone from the library.
    private func merge(into target: FollowedSeries) async -> String? {
        do {
            // The edition this screen shows, and no other, as on a removal.
            try await SeriesAPI.merge(seriesId: seriesId, language: language, into: target.seriesId)
            merged = true
            return nil
        } catch {
            return reportError(error)
        }
    }

    /// Adds a missing volume as a full record: the title lookup — the same AI
    /// call as a title typed in the add sheet — writes its summary, genre, pages
    /// and cover, and the volume is filed under this saga at its number, so its
    /// row here turns into the reader's book as soon as the list reloads.
    ///
    /// The lookup spends a scan. When it cannot run — no scan left, the model
    /// down — the volume is still added, with what the catalogue knows.
    private func add(
        _ volume: Volume,
        author: String,
        as format: BookFormat? = nil,
        status: ReadingStatus = .toRead
    ) async {
        addingTitle = volume.title
        defer { addingTitle = nil }
        let format = format ?? takenFormat
        // A recording takes Audible's own record of it — cover, narrators,
        // running time — read through the reader's account. Without an
        // account, or a recording Audible does not sell, the volume is added
        // by its title below, as a book is.
        if format == .audiobook, volume.kind == .main, let number = volume.number, let language {
            var heard: Book?
            do {
                heard = try await SeriesAPI.addAudibleVolume(
                    seriesId: seriesId,
                    volume: number,
                    language: language
                )
            } catch {
                let code = (error as? APIError)?.domainCode
                if code != "NOT_FOUND" && code != "AUDIBLE_NOT_CONNECTED" { _ = reportError(error) }
            }
            if var added = heard {
                track(.bookAdded(source: .series))
                // Audible's record lands on the pile: one already heard is
                // moved to the books read, which stamps its finish. Failing
                // that, it stays on the pile rather than being added twice.
                if status != .toRead {
                    do {
                        added = try await BookAPI.setStatus(id: added.id, status: status)
                    } catch {
                        errorMessage = reportError(error)
                    }
                }
                owned.append(added)
                return
            }
        }
        // A saga read on the Kindle goes on being read there.
        let media = owned.first { $0.format != .audiobook }
            .map(\.media).flatMap { $0.isEmpty ? nil : $0 } ?? [.print]
        let membership = SeriesMembership(
            id: seriesId,
            name: series?.name ?? owned.first?.series?.name ?? volume.title,
            volume: volume.number,
            kind: volume.kind
        )
        var draft = BookDraft(title: volume.title, authors: [author], format: format, media: media)
        // A provisional volume is titled after its saga and has no title to
        // look up: it is added bare, at its number, and described later.
        let canLookUp = series?.isProvisional != true
        if canLookUp, let found = try? await ScanAPI.lookUp(title: "\(volume.title) — \(author)"), found.recognized {
            draft = found.asDraft
            if draft.title.isEmpty { draft.title = volume.title }
            if draft.authors.isEmpty { draft.authors = [author] }
            draft.format = format
            draft.media = media
        }
        // Filed here whatever the lookup answered: the catalogue is what says
        // which volume this is, and the row it fills. In the edition of this
        // row, too: the Series tab shelves a saga once per language, and a
        // volume added without one would open a second row beside the saga
        // it was meant to join.
        draft.series = membership
        draft.language = language ?? owned.first?.language
        draft.status = status
        do {
            // The new volume is the answer: it joins the shelf on screen, and
            // the catalogue and the opinion it is drawn against are unchanged.
            let added = try await BookAPI.add(draft)
            track(.bookAdded(source: .series))
            owned.append(added)
        } catch {
            errorMessage = reportError(error)
        }
    }
}

/// Where the reader stands in a saga, drawn as an activity ring: the track is
/// the published spine, the arc the part of it read. The count sits inside, so
/// the ring is read at a glance and the figure checked in the same place.
struct SeriesRing: View {
    let read: Int
    let total: Int

    private var fraction: Double { total > 0 ? Double(read) / Double(total) : 0 }
    private var complete: Bool { total > 0 && read == total }
    private var tint: Color { complete ? .green : .pink }

    var body: some View {
        GeometryReader { proxy in
            let lineWidth = proxy.size.width * 0.14
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.75), tint],
                            center: .center,
                            startAngle: .zero,
                            endAngle: .degrees(360 * max(fraction, 0.01))
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                // One line, no spaces, in the weight of the count: "3/7".
                Text(verbatim: "\(read)/\(total)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, lineWidth)
            }
            .padding(lineWidth / 2)
        }
        .animation(.easeOut(duration: 0.6), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(read) tomes lus sur \(total) parus"))
    }
}

#Preview("Ring") {
    HStack(spacing: 24) {
        SeriesRing(read: 0, total: 7).frame(width: 84, height: 84)
        SeriesRing(read: 3, total: 7).frame(width: 84, height: 84)
        SeriesRing(read: 7, total: 7).frame(width: 84, height: 84)
    }
    .padding()
}

/// The friend whose shelf a saga screen was opened from.
struct SeriesFriend: Hashable, Sendable {
    let id: String
    let name: String
}

/// The friend's name under the title, as their other screens carry it.
private struct FriendSubtitle: ViewModifier {
    let name: String?

    func body(content: Content) -> some View {
        if let name {
            content.navigationSubtitle(name)
        } else {
            content
        }
    }
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
