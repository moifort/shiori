import SwiftUI

/// Everything a saga's page can ask for.
enum SeriesAction {
    case openBook(Book)
    case rate
    case editGenre
    /// The bell: the saga followed again, or set aside.
    case setFollowed(Bool)
    case openAuthor(AuthorDestination)
    /// A volume announced in the edition opened, on its own page.
    case openAnnounced(DiscoveredVolume)
    /// A volume the reader does not hold, added in the format and status asked.
    case add(Volume, author: String, format: BookFormat, status: ReadingStatus)
    case retry
    /// The reader counts the volumes of a saga nobody catalogued.
    case declareVolumeCount
}

/// One saga in the TV app's grammar, as the book page is drawn: a hero of
/// three covers fanned over the colours of the volume to read next, the
/// saga's name and its author; where the reader stands in the white capsule
/// of the home's saga card, the saga's own stars and the bell that follows it
/// on Liquid Glass. Then, without cards around them: the next volume announced
/// as the home's lead card, the saga in figures, its summary, its volumes and
/// its annexes as rows of posters, and its facts as the book page's table.
///
/// The owned volumes are the reader's own books; the missing ones are dimmed,
/// and a tap offers to add them. Opened from a friend's shelf, the same
/// catalogue reads as theirs: the capsule, the stars, the days and the volumes
/// held are the friend's, read-only.
struct SeriesPage: View {
    let series: BookSeries?
    /// Every volume of the saga held, numbered or not.
    let owned: [Book]
    let opinion: SeriesOpinion?
    let isLoading: Bool
    let errorMessage: String?
    /// The language of the edition opened; nil until it has loaded.
    let language: BookLanguage?
    /// The friend whose shelf it is: read-only.
    let friend: SeriesFriend?
    let isFollowed: Bool
    /// The volume being added, its poster turning.
    let addingTitle: String?
    let releases: SagaReleases?
    /// The format a volume is offered in, as the saga is read.
    let takenFormat: BookFormat
    /// The page of an announced volume, when the release watch found it.
    let announcedVolume: (Volume) -> DiscoveredVolume?
    let onAction: (SeriesAction) async -> Void

    /// Bumped on each tap of the bell, which swings as a bell rings.
    @State private var rings = 0

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        if isLoading && series == nil && owned.isEmpty {
            // Reading what is stored: the AI building a catalogue nobody
            // had is said in the bar, over the volumes held.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(String(localized: "Série"))
                .navigationBarTitleDisplayMode(.inline)
        } else if let series {
            // No title in the bar: the hero names the saga under it, as the
            // book page names its book.
            catalogue(series)
                .navigationBarTitleDisplayMode(.inline)
                .modifier(FriendSubtitle(name: friend?.name))
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
            .navigationTitle(owned.first?.series?.name ?? String(localized: "Série"))
            .navigationBarTitleDisplayMode(.inline)
            .modifier(FriendSubtitle(name: friend?.name))
        }
    }

    private func catalogue(_ series: BookSeries) -> some View {
        let standing = progress(series)
        return ScrollView {
            VStack(spacing: 0) {
                hero(series, standing: standing)
                VStack(alignment: .leading, spacing: 28) {
                    VStack(spacing: 22) {
                        releaseCard(series)
                        figures(series, standing: standing)
                    }
                    if let description = series.description {
                        BookSynopsisBlock(synopsis: description)
                    }
                    rail("Tomes", volumes: series.spine, author: series.author, ringed: ringedId(series))
                    if !series.relatedWorks.isEmpty {
                        rail("Annexes", volumes: series.relatedWorks, author: series.author, ringed: nil)
                    }
                    facts(series)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Hero

    private func hero(_ series: BookSeries, standing: (read: Int, published: Int)) -> some View {
        let author = authorDestination(series)
        return SeriesHero(
            name: series.name,
            author: series.author,
            fan: fan(series),
            language: language,
            onOpenAuthor: author.map { author in { Task { await onAction(.openAuthor(author)) } } }
        ) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ProgressCapsule(read: standing.read, total: standing.published)
                    ratingButton
                    // Following is the reader's: not on a friend's shelf, nor
                    // over a saga they hold nothing of.
                    if friend == nil, !owned.isEmpty { bell }
                }
            }
        }
    }

    /// The saga's own stars on glass, as the book hero's rating button: not
    /// the average of its volumes — a cycle can be worth more than its books,
    /// or rather less. The way to give them while there are none. A friend's
    /// stars and heart, read-only.
    @ViewBuilder private var ratingButton: some View {
        let label = HStack(spacing: 6) {
            if let rating = opinion?.rating {
                RatingStars(rating: rating, font: .subheadline, monochrome: true)
            } else if friend == nil {
                Image(systemName: "star")
                Text("Noter")
            }
            if friend != nil, opinion?.favorite == true {
                Image(systemName: "heart.fill")
                    .accessibilityLabel(Text("Coup de cœur"))
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 16)
        .frame(height: ProgressCapsule.height)
        // A saga hearted already says what the reader thinks of it: no
        // prompt to rate it beside the heart, only the stars once given.
        if friend == nil, opinion?.rating != nil || opinion?.favorite != true {
            Button { Task { await onAction(.rate) } } label: { label.contentShape(.capsule) }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityIdentifier(opinion?.rating != nil ? "series-rating" : "series-rate")
        } else if friend != nil, opinion?.rating != nil || opinion?.favorite == true {
            label
                .glassEffect(.regular, in: .capsule)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("series-friend-rating")
        }
    }

    /// The only way to follow the saga or set it aside: a tap swings it as a
    /// bell rings, then strikes it through or clears it.
    private var bell: some View {
        Button {
            rings += 1
            Task { await onAction(.setFollowed(!isFollowed)) }
        } label: {
            Image(systemName: isFollowed ? "bell" : "bell.slash")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
                .symbolEffect(.wiggle, value: rings)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: ProgressCapsule.height, height: ProgressCapsule.height)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .sensoryFeedback(.selection, trigger: rings)
        .accessibilityLabel(Text(isFollowed ? "Ne plus suivre" : "Suivre"))
        .accessibilityIdentifier(isFollowed ? "series-unfollow" : "series-follow")
    }

    // MARK: - Blocks

    /// The next volume announced in the edition opened, unless the reader
    /// added it ahead of its day.
    @ViewBuilder
    private func releaseCard(_ series: BookSeries) -> some View {
        if friend == nil, let next = releases?.next, !heldNumbers.contains(next.number) {
            SeriesReleaseCard(volume: next, author: series.author, isAudio: series.isAudio) {
                Task { await onAction(.openAnnounced(next)) }
            }
        }
    }

    /// The saga in figures, as the home sets the year's: the volumes read, on
    /// the pile, out, announced, and how long the ones held run.
    private func figures(_ series: BookSeries, standing: (read: Int, published: Int)) -> some View {
        let main = owned.filter { $0.series?.kind == .main }
        let announced = series.spine.count { $0.isForthcoming(asOf: currentYear, in: language, datedUpTo: datedUpTo) }
        var items = [
            FiguresLine.Item(value: standing.read.formatted(), label: series.isAudio ? String(localized: "écoutés") : String(localized: "lus")),
            FiguresLine.Item(value: main.count { $0.status == .toRead }.formatted(), label: String(localized: "à lire")),
            FiguresLine.Item(value: standing.published.formatted(), label: String(localized: "tomes")),
        ]
        if announced > 0 {
            items.append(FiguresLine.Item(value: announced.formatted(), label: announced == 1 ? String(localized: "annoncé") : String(localized: "annoncés")))
        }
        let minutes = owned.compactMap(\.durationMinutes).reduce(0, +)
        let pages = owned.compactMap(\.pageCount).reduce(0, +)
        if series.isAudio, minutes > 0 {
            items.append(FiguresLine.Item(value: "\((minutes / 60).formatted())h", label: String(localized: "d'écoute")))
        } else if pages > 0 {
            items.append(FiguresLine.Item(value: FiguresLine.compact(pages), label: String(localized: "pages")))
        }
        return FiguresLine(items: items)
            .accessibilityIdentifier("series-figures")
    }

    // MARK: - Volumes

    /// A row of posters, one per volume in catalogue order — a poster per
    /// part of a novel sold in two, and per format held.
    private func rail(_ title: LocalizedStringKey, volumes: [Volume], author: String, ringed: String?) -> some View {
        SeriesPosterRail(title: title, items: posters(volumes), ringedId: ringed) { poster in
            switch poster.kind {
            case let .owned(book, volume): ownedPoster(book, volume: volume)
            case let .missing(volume): missingPoster(volume, author: author)
            }
        }
    }

    private struct Poster: Identifiable {
        enum Kind {
            case owned(Book, Volume)
            case missing(Volume)
        }

        let id: String
        let kind: Kind
    }

    private func posters(_ volumes: [Volume]) -> [Poster] {
        volumes.flatMap { volume in
            // Matched by kind and number, or by title for an unnumbered
            // related work: a volume just added from here takes its place
            // back on reload.
            let books = owned.filter(volume.matches)
            if books.isEmpty { return [Poster(id: "missing-\(volume.id)", kind: .missing(volume))] }
            return books.map { Poster(id: $0.id, kind: .owned($0, volume)) }
        }
    }

    private func caption(_ volume: Volume) -> String {
        volume.number.map { String(localized: "Tome \($0)") } ?? volume.kind.label
    }

    private func ownedPoster(_ book: Book, volume: Volume) -> some View {
        Button { Task { await onAction(.openBook(book)) } } label: {
            PosterCover(book: book, caption: caption(volume), showsAudioTag: false)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(book.title), \(caption(volume)), \(book.status.label)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("series-volume-owned")
    }

    /// A volume the reader does not hold, dimmed and without a badge. Out, a
    /// tap offers to add it; announced, its day replaces its number, in
    /// white like the others, and a tap opens its page once the release watch
    /// found one.
    @ViewBuilder
    private func missingPoster(_ volume: Volume, author: String) -> some View {
        // The edition opened names it and dates it when the release watch
        // found it there: the French volume 5 comes out on its own day.
        let release = language.flatMap { volume.release(in: $0) }
        let title = release?.title ?? volume.title
        let forthcoming = volume.isForthcoming(asOf: currentYear, in: language, datedUpTo: datedUpTo)
        let day = forthcoming ? release.map { ReleaseDateText.short($0.date) } : nil
        // An announced volume shows the edition's cover once the watch found
        // one, dimmed, its day in white over the blurred foot.
        let coverURL = release?.coverURL
            ?? (forthcoming ? announcedVolume(volume)?.coverURL : nil)
            ?? releases?.next.flatMap { $0.number == volume.number && volume.kind == .main ? $0.coverURL : nil }
        let cover = Group {
            if let day, coverURL == nil {
                // No cover found yet: a blank, rather than a placeholder
                // printing the title under the day.
                BlankPoster(caption: day)
            } else {
                PosterCover(
                    book: Book(
                        id: volume.id,
                        title: title,
                        authors: [author],
                        format: series?.isAudio == true ? .audiobook : .book,
                        coverURL: coverURL,
                        status: .toRead
                    ),
                    caption: day ?? caption(volume),
                    showsAudioTag: false,
                    dimming: day == nil ? 0.12 : 0.5
                )
                // A volume out the reader lacks is dimmed whole; an announced
                // one keeps its day bright.
                .opacity(day == nil ? 0.45 : 1)
            }
        }
        .overlay {
            if addingTitle == volume.title { ProgressView() }
        }
        .contentShape(.rect)
        let label = Text(forthcoming ? "\(title), \(caption(volume)), à paraître" : "\(title), \(caption(volume)), à ajouter")

        if forthcoming {
            if let page = announcedVolume(volume) {
                Button { Task { await onAction(.openAnnounced(page)) } } label: { cover }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("series-volume-announced")
            } else {
                cover
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
            }
        } else if friend != nil {
            // A volume the friend lacks: nothing is offered.
            cover
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
        } else {
            Menu {
                ForEach(takenFormat.takenAs, id: \.self) { format in
                    Section(format.label) {
                        Button(
                            format == .audiobook ? "À écouter" : "À lire",
                            systemImage: "bookmark.fill"
                        ) {
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
                cover
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .disabled(addingTitle != nil)
            .accessibilityLabel(Text("Ajouter « \(title) » à ma bibliothèque"))
            .accessibilityIdentifier("series-volume-add")
        }
    }

    // MARK: - Facts

    /// What the saga is, as the book page's table: the reader's days with it
    /// three to a row, then its genre — which every volume held takes — its
    /// format, its publisher, since when it comes out and how long it runs.
    private func facts(_ series: BookSeries) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Informations")
            FactGrid(groups: [
                FactGroup(tiles: dayTiles, columns: 3),
                FactGroup(tiles: factTiles(series)),
            ])
            if series.isProvisional {
                Text("Catalogue provisoire, dessiné d'après le nombre de tomes que vous avez indiqué.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dayTiles: [FactTile] {
        // As the book page dates its reading: the day and the month.
        let day: (Date?) -> String? = { $0?.formatted(.dateTime.day().month(.abbreviated)) }
        return [
            FactTile(id: "addedAt", title: "Ajoutée", value: day(addedAt), placeholder: "—"),
            FactTile(id: "startedAt", title: "Commencée", value: day(startedAt), placeholder: "—"),
            FactTile(id: "finishedAt", title: "Terminée", value: day(finishedAt), placeholder: "—"),
        ]
    }

    private func factTiles(_ series: BookSeries) -> [FactTile] {
        let volume = owned.first
        let editable = friend == nil && volume != nil
        let firstYear = series.spine.compactMap(\.publishedIn).min()
        let format = volume?.format ?? (series.isAudio ? .audiobook : .book)
        // The publisher most of the volumes held carry.
        let publisher = Dictionary(grouping: owned.compactMap(\.publisher), by: { $0 })
            .max { $0.value.count < $1.value.count }?.key
        var tiles = [
            FactTile(
                id: "genre",
                title: "Genre",
                value: volume?.genre?.label,
                chips: volume?.subgenres ?? [],
                isWide: true,
                showsChevron: editable,
                action: editable ? { Task { await onAction(.editGenre) } } : nil
            ),
            FactTile(id: "format", title: "Format", value: format.label),
            FactTile(id: "publisher", title: "Éditeur", value: publisher),
            FactTile(
                id: "firstPublishedIn",
                title: "Parution",
                value: firstYear.map { String(localized: "Depuis \(String($0))") }
            ),
        ]
        let minutes = owned.compactMap(\.durationMinutes).reduce(0, +)
        let pages = owned.compactMap(\.pageCount).reduce(0, +)
        if series.isAudio {
            tiles.append(FactTile(id: "duration", title: "Durée", value: minutes > 0 ? "\(minutes / 60) h" : nil))
        } else {
            tiles.append(FactTile(id: "pageCount", title: "Pages", value: pages > 0 ? pages.formatted() : nil))
        }
        return tiles
    }

    // MARK: - Reading

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

    /// How far the edition opened was dated: past it, a volume out elsewhere
    /// is not out in this language yet.
    private var datedUpTo: Int? { series?.spine.datedUpTo(in: language, catalogedAt: series?.catalogedAt) }

    /// How far the reader is along the spine, in the edition opened: the volumes
    /// out, and the ones announced to the day — the next one is then awaited,
    /// and the capsule says 4 of 5. A volume announced for a month or a year is
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

    /// The volume to read next: the one open, else the first on the pile.
    private var nextToRead: Book? {
        let main = owned
            .filter { $0.series?.kind == .main }
            .sorted { ($0.series?.volume ?? .max) < ($1.series?.volume ?? .max) }
        return main.first { $0.status == .reading } ?? main.first { $0.status == .toRead }
    }

    /// The poster ringed and scrolled to: the volume to read next, else the
    /// first the reader lacks.
    private func ringedId(_ series: BookSeries) -> String? {
        if let next = nextToRead { return next.id }
        return posters(series.spine).first {
            if case .missing = $0.kind { true } else { false }
        }?.id
    }

    /// The hero's covers: the volume to read next between its neighbours, a
    /// volume the reader lacks drawn as the edition's cover when the watch
    /// found one. Centred on the first volume not read when none is next.
    private func fan(_ series: BookSeries) -> SeriesFan {
        let volumes = series.spine.map { volume in
            owned.first(where: volume.matches) ?? Book(
                id: volume.id,
                title: language.flatMap { volume.release(in: $0) }?.title ?? volume.title,
                authors: [series.author],
                format: series.isAudio ? .audiobook : .book,
                coverURL: language.flatMap { volume.release(in: $0) }?.coverURL,
                status: .toRead
            )
        }
        let centre = nextToRead.flatMap { next in series.spine.firstIndex { $0.matches(next) } }
            ?? volumes.firstIndex { $0.status != .read }
            ?? volumes.count - 1
        return SeriesFan(volumes: volumes, centredOn: centre)
    }

    /// The saga's author with the key of their page, from a volume held that
    /// names them. Nil when none carries the key.
    private func authorDestination(_ series: BookSeries) -> AuthorDestination? {
        let authors = owned.flatMap(\.authorDestinations)
        return authors.first { $0.name == series.author } ?? owned.first?.authorDestinations.first
    }

    /// The numbers of the main volumes the reader holds.
    private var heldNumbers: Set<Int> {
        Set(owned.compactMap { $0.series?.kind == .main ? $0.series?.volume : nil })
    }
}

/// A volume announced, as a poster not printed yet: a dimmed blank the size
/// of the others, its light rim, and its day in white in the foot.
private struct BlankPoster: View {
    let caption: String

    var body: some View {
        RoundedRectangle(cornerRadius: PosterCover.cornerRadius, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(white: 0.23), Color(white: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 102, height: 153)
            // The foot darker, where a cover would melt into its blur.
            .overlay {
                LinearGradient(
                    stops: [.init(color: .clear, location: 0.45), .init(color: .black.opacity(0.35), location: 0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(.rect(cornerRadius: PosterCover.cornerRadius, style: .continuous))
            }
            .overlay(alignment: .bottom) {
                Text(verbatim: caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.bottom, 9)
            }
            .overlay {
                RoundedRectangle(cornerRadius: PosterCover.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
    }
}

/// Where the reader stands in a saga, in the white capsule of the home's saga
/// card: the bar across what is read, then how many of how many.
private struct ProgressCapsule: View {
    let read: Int
    let total: Int

    static let height: CGFloat = 50

    private var fraction: CGFloat {
        total > 0 ? CGFloat(min(read, total)) / CGFloat(total) : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(.black.opacity(0.16))
                .frame(minWidth: 40, maxWidth: .infinity)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.black)
                            .frame(width: proxy.size.width * fraction)
                    }
                }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(read.formatted()).font(.title3.weight(.bold))
                Text(verbatim: "/\(total.formatted())")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.5))
            }
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
        }
        .foregroundStyle(.black)
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(.white, in: .capsule)
        .shadow(color: .black.opacity(0.45), radius: 11, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(read) tomes lus sur \(total)"))
        .accessibilityIdentifier("series-progress")
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
            addingTitle: nil,
            releases: Showcase.sagaReleases(seriesId: SeriesFixtures.followed[0].seriesId),
            takenFormat: .book, announcedVolume: { _ in nil }
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
