import SwiftUI

/// Everything a saga's page can ask for.
enum SeriesAction {
    case openBook(Book)
    case rate
    case editGenre
    /// A volume announced in the edition opened, on its own page.
    case openAnnounced(DiscoveredVolume)
    /// A volume the reader does not hold, added in the format and status asked.
    case add(Volume, author: String, format: BookFormat, status: ReadingStatus)
    case retry
    /// The reader counts the volumes of a saga nobody catalogued.
    case declareVolumeCount
}

/// One saga, laid out like the book screen: a main section with where the
/// reader stands as a ring, what the saga is, its genre and subgenres, the
/// reader's rating of it and the dates of their reading; then every volume in
/// the order of the cycle, drawn as the library draws its rows.
///
/// The owned volumes are the reader's own books; the missing ones are
/// proposals, dimmed, with a button to add them. Opened from a friend's shelf,
/// the same catalogue reads as theirs: the ring, the dates, the stars and the
/// volumes held are the friend's, read-only.
struct SeriesPage: View {
    let series: BookSeries?
    /// Every volume of the saga held, numbered or not.
    let owned: [Book]
    let opinion: SeriesOpinion?
    let isLoading: Bool
    let errorMessage: String?
    /// The edition opened; nil when every edition shows.
    let language: BookLanguage?
    /// The friend whose shelf it is: read-only.
    let friend: SeriesFriend?
    let isFollowed: Bool
    /// The volume being added, its "+" turning.
    let addingTitle: String?
    let releases: SagaReleases?
    /// The format a volume is offered in, as the saga is read.
    let takenFormat: BookFormat
    /// The page of an announced volume, when the release watch found it.
    let announcedVolume: (Volume) -> DiscoveredVolume?
    let onAction: (SeriesAction) async -> Void

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var isFavorite: Bool { opinion?.favorite == true }

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
                EmptyState(
                    systemImage: "square.stack.3d.up.slash",
                    title: "Série non cataloguée",
                    verbatim: errorMessage ?? String(localized: "Shiori n'a pas réussi à constituer le catalogue de cette série. Réessayez plus tard, ou scannez la couverture d'un de ses tomes."),
                    primary: .init("Réessayer", systemImage: "arrow.clockwise") { await onAction(.retry) },
                    secondary: owned.isEmpty || friend != nil
                        ? nil
                        : .init("Indiquer le nombre de tomes", systemImage: "number") {
                            Task { await onAction(.declareVolumeCount) }
                        }
                )
            }
        }
        .navigationTitle(series?.name ?? String(localized: "Série"))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(FriendSubtitle(name: friend?.name))
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
                    open: { volume in Task { await onAction(.openAnnounced(volume)) } }
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
            Button { Task { await onAction(.rate) } } label: {
                Label {
                    LabeledContent("Note") { RatingStars(rating: rating) }
                } icon: {
                    Image(systemName: "star").foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
            .accessibilityIdentifier("series-rating")
        } else {
            Button { Task { await onAction(.rate) } } label: {
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
                LabeledContent("Note de \(friend.name)") { RatingStars(rating: rating) }
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

    /// The genre and its subgenres on one tappable row, as on the book screen
    /// — read-only on a friend's shelf, where it is theirs to correct.
    @ViewBuilder
    private var genreRow: some View {
        if friend == nil {
            Button { Task { await onAction(.editGenre) } } label: { genreLabel(editable: true) }
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
            Button { Task { await onAction(.openBook(book)) } } label: {
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
        .onTapGesture { if let page { Task { await onAction(.openAnnounced(page)) } } }
        .accessibilityAddTraits(page == nil ? [] : .isButton)
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
                        Button("À lire", systemImage: "bookmark.fill") {
                            Task { await onAction(.add(volume, author: author, format: format, status: .toRead)) }
                        }
                        .accessibilityIdentifier("series-volume-add-pile-\(format.rawValue)")
                        Button(
                            format == .audiobook ? "Déjà écouté" : "Déjà lu",
                            systemImage: "checkmark"
                        ) {
                            Task { await onAction(.add(volume, author: author, format: format, status: .read)) }
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

    /// How far the edition opened was dated: past it, a volume out elsewhere
    /// is not out in this language yet.
    private var datedUpTo: Int? { series?.spine.datedUpTo(in: language, catalogedAt: series?.catalogedAt) }

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

    /// The numbers of the main volumes the reader holds.
    private var heldNumbers: Set<Int> {
        Set(owned.compactMap { $0.series?.kind == .main ? $0.series?.volume : nil })
    }
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

#if DEBUG
#Preview("Saga in progress") {
    let screen = SeriesFixtures.screen
    NavigationStack {
        SeriesPage(
            series: screen.series, owned: screen.owned, opinion: screen.opinion,
            isLoading: false, errorMessage: nil, language: .fr, friend: nil, isFollowed: true,
            addingTitle: nil, releases: nil, takenFormat: .book, announcedVolume: { _ in nil }
        ) { _ in }
    }
}

#Preview("Not catalogued") {
    NavigationStack {
        SeriesPage(
            series: nil, owned: [.preview], opinion: nil, isLoading: false, errorMessage: nil,
            language: .fr, friend: nil, isFollowed: true, addingTitle: nil, releases: nil,
            takenFormat: .book, announcedVolume: { _ in nil }
        ) { _ in }
    }
}
#endif
