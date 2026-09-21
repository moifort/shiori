import SwiftUI

/// One saga's full catalogue: where the reader stands as a ring, what the saga
/// is about, then every volume in the order of the cycle — the ones the reader
/// owns, the ones they are missing and the ones not out yet.
///
/// A list rather than a shelf scrolling sideways: every volume is on screen at
/// once, its title whole, and the reader finds the next one to read without
/// swiping for it.
///
/// Where the reader stands with a volume is said once, by the badge on its
/// cover — the same badge as in the library. A second word under the title
/// said it again and, read off a different field, sometimes said otherwise.
///
/// Everything unowned here is a proposal. Nothing enters the library until the
/// reader adds it, which is what keeps their list theirs.
struct SeriesView: View {
    let seriesId: String

    @State private var series: BookSeries?
    @State private var ownedByNumber: [Int: Book] = [:]
    /// Every volume of the saga the reader holds, numbered or not: what the
    /// genre is read off and corrected through.
    @State private var owned: [Book] = []
    @State private var isEditingGenre = false
    @State private var opinion: SeriesOpinion?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addingTitle: String?
    /// A rating or a heart is on its way to the server.
    @State private var isSaving = false
    /// The owned volume the reader tapped, opened over the shelf.
    @State private var selectedBook: Book?

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    /// The library row's cover, so a volume looks the same in both lists.
    private let coverWidth: CGFloat = 44

    var body: some View {
        Group {
            if isLoading {
                // Labelled because the first opening of a saga an import named
                // is where the server builds its catalogue, which takes a while.
                ProgressView("Chargement du catalogue…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let series {
                catalogue(series)
            } else {
                ContentUnavailableView {
                    Label("Série non cataloguée", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text(errorMessage ?? "Shiori n'a pas réussi à constituer le catalogue de cette série. Réessayez plus tard, ou scannez la couverture d'un de ses tomes.")
                }
            }
        }
        .navigationTitle(series?.name ?? "Série")
        .navigationBarTitleDisplayMode(.inline)
        // In the corner even when the catalogue is missing: what a reader thinks
        // of a saga does not wait on the world having described it.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AsyncToolbarButton(
                    title: isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                    systemImage: isFavorite ? "heart.fill" : "heart"
                ) {
                    await setFavorite(!isFavorite)
                }
                .tint(isFavorite ? .pink : nil)
                .accessibilityIdentifier("series-favorite")
            }
        }
        // The stars commit on the tap and the control cannot show the call
        // itself, so the wait is made visible by a scrim, as on the book sheet.
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        .disabled(isSaving)
        .sheet(item: $selectedBook) { book in
            BookView(
                bookId: book.id,
                onChanged: { _ in Task { await load() } },
                onDeleted: { _ in Task { await load() } }
            )
        }
        .sheet(isPresented: $isEditingGenre) {
            if let volume = owned.first {
                // Saved on one volume; the server carries a genre to every
                // volume of the saga, so the whole shelf follows.
                GenreEditSheet(book: volume) { correction in
                    do {
                        _ = try await BookAPI.update(id: volume.id, correction: correction)
                        await load()
                        return nil
                    } catch {
                        return reportError(error)
                    }
                }
            }
        }
        .task { await load() }
    }

    private func catalogue(_ series: BookSeries) -> some View {
        List {
            header(series)
            if !owned.isEmpty { genreSection }
            volumes("Tomes", volumes: series.spine, author: series.author, footer: nil)
            if !series.relatedWorks.isEmpty {
                volumes(
                    "Récits annexes",
                    volumes: series.relatedWorks,
                    author: series.author,
                    footer: "Préquelles, nouvelles et hors-séries, en dehors de la numérotation."
                )
            }
            ratingSection
        }
        .listStyle(.insetGrouped)
    }

    /// Where the reader stands, as a ring they can read without reading, and
    /// beside it what the saga is: its name, its author, its size. The summary
    /// runs underneath, the full width of the card.
    private func header(_ series: BookSeries) -> some View {
        let standing = progress(series)
        return Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    SeriesRing(read: standing.read, total: standing.published)
                        .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(series.name)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(series.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(series.spine.count) tome(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
                if let description = series.description {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    /// The saga's genre and subgenres, corrected here for every volume at once
    /// rather than book by book.
    private var genreSection: some View {
        let volume = owned.first
        return Section {
            Button { isEditingGenre = true } label: {
                HStack(spacing: 12) {
                    if let genre = volume?.genre {
                        genre.image.foregroundStyle(genre.tint).frame(width: 24)
                    } else {
                        Image(systemName: "theatermasks").foregroundStyle(.secondary).frame(width: 24)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(volume?.genre?.label ?? String(localized: "Genre non renseigné"))
                            .foregroundStyle(.primary)
                        if let subgenres = volume?.subgenres, !subgenres.isEmpty {
                            Text(subgenres.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityIdentifier("series-genre")
        } header: {
            Text("Genre")
        } footer: {
            Text("Appliqué à tous les tomes de la série dans votre bibliothèque.")
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

    /// One volume. Owned, it opens and its cover carries the reader's status;
    /// missing, it is dimmed and offers to be added; not out yet, it says when.
    @ViewBuilder
    private func volumeRow(_ volume: Volume, author: String) -> some View {
        let owned = volume.number.flatMap { ownedByNumber[$0] }
        if let owned {
            Button { selectedBook = owned } label: { volumeBody(volume, owned: owned, author: author) }
                .tint(.primary)
                .accessibilityIdentifier("series-volume-owned")
        } else {
            volumeBody(volume, owned: nil, author: author)
        }
    }

    private func volumeBody(_ volume: Volume, owned: Book?, author: String) -> some View {
        // A volume the reader does not own is still drawn as a book: the
        // library's stand-in, initials on a hue derived from the title, dimmed
        // so the list says at a glance what is theirs and what is not.
        let drawn = owned
            ?? Book(id: volume.id, title: volume.title, authors: [author], status: .toRead)
        return HStack(alignment: .center, spacing: 12) {
            BookCover(book: drawn, width: coverWidth)
                .opacity(owned == nil ? 0.5 : 1)
                .overlay(alignment: .topTrailing) {
                    if let owned {
                        ReadingStatusBadge(status: owned.status)
                            .scaleEffect(0.85)
                            .offset(x: 6, y: -4)
                    }
                }
                .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.number.map { "\(volume.kind.label) \($0)" } ?? volume.kind.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(volume.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(owned == nil ? Color.secondary : Color.primary)
                    .multilineTextAlignment(.leading)
                Group {
                    if volume.isForthcoming(asOf: currentYear), let year = volume.publishedIn {
                        Text("à paraître en \(String(year))")
                    } else if let year = volume.publishedIn {
                        Text(verbatim: String(year))
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            // The badge is icon-only, so the status is spoken here.
            .accessibilityValue(Text(owned?.status.label ?? ""))
            Spacer(minLength: 8)
            if owned == nil { action(volume, author: author) }
        }
    }

    /// What can be done with a volume the reader does not hold: add it, or
    /// nothing yet when it is not out.
    @ViewBuilder
    private func action(_ volume: Volume, author: String) -> some View {
        if volume.isForthcoming(asOf: currentYear) {
            // Nothing to add: the volume does not exist yet. Batch 4 will
            // attach an alert here rather than an action.
            Image(systemName: "clock")
                .foregroundStyle(.tertiary)
                .accessibilityLabel(Text("Pas encore paru"))
        } else if addingTitle == volume.title {
            ProgressView().controlSize(.small)
        } else {
            Button { Task { await add(volume, author: author) } } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Ajouter « \(volume.title) » à ma liste à lire"))
        }
    }

    private var ratingSection: some View {
        Section {
            // The saga's own rating, not the average of its volumes: a cycle
            // can be worth more than its books — the shape only shows at the
            // end — or rather less, when three good ones are followed by four
            // that should not exist.
            InteractiveStarRating(
                rating: Binding(
                    get: { opinion?.rating ?? 0 },
                    set: { stars in Task { await rate(stars) } }
                ),
                allowsUnset: true
            )
            .accessibilityIdentifier("series-rating")
        } header: {
            Text("Votre note de la série")
        } footer: {
            Text("Indépendante des notes que vous donnez à chaque tome.")
        }
    }

    /// How far the reader is along the published spine. Announced volumes are
    /// left out: they would make a finished saga look unfinished for years.
    private func progress(_ series: BookSeries) -> (read: Int, published: Int) {
        let published = series.spine.filter { !$0.isForthcoming(asOf: currentYear) }
        let read = published.filter { volume in
            guard let number = volume.number else { return false }
            return ownedByNumber[number]?.status == .read
        }
        return (read.count, published.count)
    }

    private func load() async {
        isLoading = true
        do {
            series = try await SeriesAPI.series(id: seriesId)
            opinion = try await SeriesAPI.opinion(seriesId: seriesId)
            let mine = try await LibraryAPI.library()
            owned = mine.filter { $0.seriesId == seriesId }.flatMap(\.books)
            ownedByNumber = Dictionary(
                owned.compactMap { book in book.series?.volume.map { ($0, book) } },
                uniquingKeysWith: { first, _ in first }
            )
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
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

    private func setFavorite(_ favorite: Bool) async {
        isSaving = true
        defer { isSaving = false }
        do {
            opinion = try await SeriesAPI.setFavorite(seriesId: seriesId, favorite: favorite)
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func add(_ volume: Volume, author: String) async {
        addingTitle = volume.title
        defer { addingTitle = nil }
        do {
            // Another volume of a manga is a manga: the saga shares its format.
            let format = ownedByNumber.values.first?.format ?? .book
            _ = try await BookAPI.add(BookDraft(title: volume.title, authors: [author], format: format))
            track(.bookAdded(source: .series))
            await load()
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
                VStack(spacing: 0) {
                    Text(verbatim: "\(read)")
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text(verbatim: "/ \(total)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
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
