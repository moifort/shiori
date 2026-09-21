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
struct SeriesView: View {
    let seriesId: String

    @Environment(\.dismiss) private var dismiss

    @State private var series: BookSeries?
    @State private var ownedByNumber: [Int: Book] = [:]
    /// Every volume of the saga the reader holds, numbered or not: what the
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
    /// The owned volume the reader tapped, opened over the list.
    @State private var selectedBook: Book?

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
                EmptyStateView(
                    systemImage: "square.stack.3d.up.slash",
                    title: "Série non cataloguée",
                    verbatim: errorMessage ?? String(localized: "Shiori n'a pas réussi à constituer le catalogue de cette série. Réessayez plus tard, ou scannez la couverture d'un de ses tomes."),
                    primary: .init("Réessayer", systemImage: "arrow.clockwise") { await load() }
                )
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
            if !owned.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Supprimer la série", systemImage: "trash", role: .destructive) {
                            confirmDelete = true
                        }
                        .accessibilityIdentifier("series-delete")
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel(Text("Plus d'actions"))
                    .accessibilityIdentifier("series-menu")
                }
            }
        }
        .alert(
            "Supprimer la série ?",
            isPresented: $confirmDelete
        ) {
            Button("Supprimer", role: .destructive) { Task { await deleteSeries() } }
                .accessibilityIdentifier("choice-delete-series")
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les \(owned.count) livres de cette série dans votre bibliothèque seront supprimés avec elle, ainsi que votre note. Cette action est définitive.")
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
            mainSection(series)
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

            if !owned.isEmpty { genreRow }

            // The saga's own rating, not the average of its volumes: a cycle
            // can be worth more than its books — the shape only shows at the
            // end — or rather less, when three good ones are followed by four
            // that should not exist.
            Label {
                LabeledContent("Note") {
                    InteractiveStarRating(
                        rating: Binding(
                            get: { opinion?.rating ?? 0 },
                            set: { stars in Task { await rate(stars) } }
                        ),
                        allowsUnset: true
                    )
                    .accessibilityIdentifier("series-rating")
                }
            } icon: {
                Image(systemName: "star").foregroundStyle(.secondary)
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
            if !owned.isEmpty {
                Text("Le genre et les sous-genres s'appliquent à tous les tomes de la série dans votre bibliothèque.")
            }
        }
    }

    /// The genre and its subgenres on one tappable row, as on the book screen.
    private var genreRow: some View {
        let volume = owned.first
        return Button { isEditingGenre = true } label: {
            Label {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Genre") {
                        HStack(spacing: 4) {
                            if let genre = volume?.genre {
                                genre.image.imageScale(.small)
                            }
                            Text(volume?.genre?.label ?? String(localized: "Non renseigné"))
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.tint)
                    }
                    if let subgenres = volume?.subgenres, !subgenres.isEmpty {
                        TagList(tags: subgenres, systemImage: "tag")
                    }
                }
            } icon: {
                Image(systemName: "books.vertical").foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
        .accessibilityIdentifier("series-genre")
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

    /// One volume. Owned, it is the reader's own book, drawn as the library
    /// draws it and opened as the library opens it; missing, it is dimmed and
    /// offers to be added; not out yet, it says when.
    @ViewBuilder
    private func volumeRow(_ volume: Volume, author: String) -> some View {
        let label = volume.number.map { "\(volume.kind.label) \($0)" } ?? volume.kind.label
        if let book = volume.number.flatMap({ ownedByNumber[$0] }) {
            Button { selectedBook = book } label: {
                BookRow(
                    title: book.title,
                    authorLine: book.authorLine,
                    cover: book,
                    status: book.status,
                    rating: book.rating,
                    volumeLabel: label,
                    statusTag: book.status,
                    subgenre: nil,
                    isFavorite: book.favorite,
                    isHidden: book.hidden
                )
            }
            .tint(.primary)
            .accessibilityIdentifier("series-volume-owned")
        } else {
            missingRow(volume, label: label, author: author)
        }
    }

    /// A volume the reader does not hold, in the library row's layout: the
    /// placeholder cover dimmed, the number and title, when it came out, and
    /// what can be done about it.
    private func missingRow(_ volume: Volume, label: String, author: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: Book(id: volume.id, title: volume.title, authors: [author], status: .toRead))
                .opacity(0.45)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(volume.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Group {
                    if volume.isForthcoming(asOf: currentYear), let year = volume.publishedIn {
                        Text("à paraître en \(String(year))")
                    } else if let year = volume.publishedIn {
                        Text(verbatim: String(year))
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
    }

    /// What can be done with a volume the reader does not hold: add it, or
    /// nothing yet when it is not out.
    @ViewBuilder
    private func action(_ volume: Volume, author: String) -> some View {
        if volume.isForthcoming(asOf: currentYear) {
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

    // MARK: - Dates

    /// When the reader opened the first of their volumes.
    private var startedAt: Date? { owned.compactMap(\.startedAt).min() }
    /// When the first of their volumes entered the library.
    private var addedAt: Date? { owned.compactMap(\.addedAt).min() }
    /// When they finished the last of their volumes — only once every volume
    /// they hold is read: a saga with one volume still open is not finished.
    private var finishedAt: Date? {
        guard !owned.isEmpty, owned.allSatisfy({ $0.status == .read }) else { return nil }
        return owned.compactMap(\.finishedAt).max()
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

    private func deleteSeries() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await SeriesAPI.delete(seriesId: seriesId)
            dismiss()
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
