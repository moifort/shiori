import SwiftUI

/// One saga's full catalogue, drawn as a shelf: the volumes the reader owns,
/// the ones they are missing and the ones not out yet, side by side in the
/// order of the cycle. The only screen where the catalogue is shown whole.
///
/// A shelf rather than a list because a saga is a shape before it is an
/// inventory — three covers, a gap, four covers says more about where the
/// reader stands than fourteen rows of text. A volume they do not own has no
/// cover to draw, the catalogue holding a title and a year and nothing else,
/// so it takes the library's typographic stand-in, dimmed, with the add button
/// in its corner.
///
/// Everything unowned here is a proposal. Nothing enters the library until the
/// reader adds it, which is what keeps their list theirs.
struct SeriesView: View {
    let seriesId: String

    @State private var series: BookSeries?
    @State private var ownedByNumber: [Int: Book] = [:]
    @State private var opinion: SeriesOpinion?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addingTitle: String?
    /// A rating or a heart is on its way to the server.
    @State private var isSaving = false
    /// The owned volume the reader tapped, opened over the shelf.
    @State private var selectedBook: Book?

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    /// The width of one volume on the shelf. Five fit across a large phone,
    /// three and a half on the smallest, which is the point: a shelf has to run
    /// off the edge to read as one.
    private let coverWidth: CGFloat = 84

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
        .task { await load() }
    }

    private func catalogue(_ series: BookSeries) -> some View {
        List {
            header(series)
            shelf("Tomes", volumes: series.spine, author: series.author, footer: nil)
            if !series.relatedWorks.isEmpty {
                shelf(
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

    /// Who wrote the saga, what it is about, and where the reader stands in it.
    private func header(_ series: BookSeries) -> some View {
        let standing = progress(series)
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(series.author).font(.subheadline).foregroundStyle(.secondary)
                if let description = series.description {
                    Text(description).font(.callout)
                }
                stateBadge(standing)
                // Figures rather than a sentence: "3 / 14" has no plural to get
                // wrong, and the bar says the same thing without being read.
                if standing.published > 0 {
                    HStack(spacing: 10) {
                        ProgressView(value: Double(standing.read), total: Double(standing.published))
                            .tint(standing.read == standing.published ? .green : .blue)
                        Text("\(standing.read) / \(standing.published)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        Text("\(standing.read) tomes lus sur \(standing.published) parus")
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// One shelf of volumes, running off both edges of the card as the shelves
    /// on the home screen do.
    private func shelf(
        _ title: LocalizedStringKey,
        volumes: [Volume],
        author: String,
        footer: LocalizedStringKey?
    ) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(volumes) { volume in
                        tile(volume, author: author)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
            .listRowInsets(EdgeInsets())
        } header: {
            Text(title)
        } footer: {
            if let footer { Text(footer) }
        }
    }

    /// One volume: its cover or its stand-in, what it is called, and where the
    /// reader stands with it. Owned, it opens; missing, it offers to be added.
    @ViewBuilder
    private func tile(_ volume: Volume, author: String) -> some View {
        let owned = volume.number.flatMap { ownedByNumber[$0] }
        if let owned {
            Button { selectedBook = owned } label: { tileBody(volume, owned: owned, author: author) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("series-volume-owned")
        } else {
            tileBody(volume, owned: nil, author: author)
        }
    }

    private func tileBody(_ volume: Volume, owned: Book?, author: String) -> some View {
        // A volume the reader does not own is still drawn as a book: the
        // library's stand-in, initials on a hue derived from the title, dimmed
        // so the shelf says at a glance what is theirs and what is not.
        let drawn = owned
            ?? Book(id: volume.id, title: volume.title, authors: [author], status: .toRead)
        return VStack(alignment: .leading, spacing: 4) {
            BookCover(book: drawn, width: coverWidth)
                .opacity(owned == nil ? 0.5 : 1)
                .overlay(alignment: .topTrailing) {
                    corner(volume, owned: owned, author: author)
                        .offset(x: 7, y: -7)
                }
                .padding(.top, 7)
                .padding(.trailing, 7)

            Text(volume.number.map { "\(volume.kind.label) \($0)" } ?? volume.kind.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(volume.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(owned == nil ? Color.secondary : Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            standingLine(volume, owned: owned)
        }
        .frame(width: coverWidth + 7, alignment: .leading)
    }

    /// The third line, one per state so every tile is the same height: the
    /// reader's own reading of a volume they hold, when it is due for one that
    /// is not out, the year of publication otherwise.
    @ViewBuilder
    private func standingLine(_ volume: Volume, owned: Book?) -> some View {
        if let owned {
            Label(owned.status.label, systemImage: owned.status.symbol)
                .labelStyle(.caption)
                .font(.caption2)
                .foregroundStyle(owned.status == .read ? Color.green : .secondary)
                .lineLimit(1)
        } else if volume.isForthcoming(asOf: currentYear), let year = volume.publishedIn {
            Text("à paraître en \(String(year))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        } else if let year = volume.publishedIn {
            Text(String(year))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        } else {
            Text(" ").font(.caption2).hidden()
        }
    }

    /// The marker pinned to a cover's corner: owned, not out yet, or the button
    /// that adds it. Icon-only, because 84 points leave no room for a word.
    @ViewBuilder
    private func corner(_ volume: Volume, owned: Book?, author: String) -> some View {
        if owned != nil {
            badge("checkmark", tint: .green)
                .accessibilityLabel(Text("Dans votre bibliothèque"))
        } else if volume.isForthcoming(asOf: currentYear) {
            // Nothing to add: the volume does not exist yet. Batch 4 will
            // attach an alert here rather than an action.
            badge("clock", tint: .gray)
                .accessibilityLabel(Text("Pas encore paru"))
        } else if addingTitle == volume.title {
            ProgressView()
                .controlSize(.small)
                .frame(width: 24, height: 24)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
        } else {
            Button { Task { await add(volume, author: author) } } label: {
                badge("plus", tint: .accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Ajouter « \(volume.title) » à ma liste à lire"))
        }
    }

    private func badge(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(tint, in: Circle())
            // A ring in the card's own colour lifts the badge off whatever the
            // cover happens to be under it.
            .overlay(
                Circle().strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 2)
            )
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

    /// In progress, or complete once every published volume has been read.
    private func stateBadge(_ standing: (read: Int, published: Int)) -> some View {
        let complete = standing.published > 0 && standing.read == standing.published
        return Label(
            complete ? "Terminée" : "En cours",
            systemImage: complete ? "checkmark.circle.fill" : "book.fill"
        )
        .labelStyle(.caption)
        .font(.caption.weight(.medium))
        .foregroundStyle(complete ? Color.green : Color.blue)
    }

    private func load() async {
        isLoading = true
        do {
            series = try await SeriesAPI.series(id: seriesId)
            opinion = try await SeriesAPI.opinion(seriesId: seriesId)
            let mine = try await LibraryAPI.library()
            ownedByNumber = Dictionary(
                mine.filter { $0.seriesId == seriesId }
                    .flatMap(\.books)
                    .compactMap { book in book.series?.volume.map { ($0, book) } },
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
