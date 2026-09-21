import SwiftUI

/// One saga's full catalogue. The volumes the reader owns, the ones they are
/// missing, and the ones not out yet — the only screen where the catalogue is
/// shown whole.
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

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

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
        // The stars commit on the tap and the row's own control cannot show the
        // call, so the wait is made visible by a scrim, as on the book sheet.
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        .disabled(isSaving)
        .task { await load() }
    }

    private func catalogue(_ series: BookSeries) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(series.author).font(.subheadline).foregroundStyle(.secondary)
                    if let description = series.description {
                        Text(description).font(.callout)
                    }
                    stateBadge
                }
                .padding(.vertical, 4)
            }

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

            Section("Tomes") {
                ForEach(series.spine) { volume in row(volume, author: series.author) }
            }

            if !series.relatedWorks.isEmpty {
                Section {
                    ForEach(series.relatedWorks) { volume in row(volume, author: series.author) }
                } header: {
                    Text("Récits annexes")
                } footer: {
                    Text("Préquelles, nouvelles et hors-séries, en dehors de la numérotation.")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// In progress, or complete once every published volume has been read.
    /// Derived here from what is owned, exactly as the server derives it for the
    /// series tab — no counter, which is noise on a list whose point is the
    /// catalogue itself.
    private var stateBadge: some View {
        let published = (series?.spine ?? []).filter { !$0.isForthcoming(asOf: currentYear) }
        let allRead = !published.isEmpty && published.allSatisfy { volume in
            guard let number = volume.number else { return false }
            return ownedByNumber[number]?.status == .read
        }
        return Label(
            allRead ? "Terminée" : "En cours",
            systemImage: allRead ? "checkmark.circle.fill" : "book.fill"
        )
        .labelStyle(.caption)
        .font(.caption.weight(.medium))
        .foregroundStyle(allRead ? Color.green : Color.blue)
    }

    private func row(_ volume: Volume, author: String) -> some View {
        let owned = volume.number.flatMap { ownedByNumber[$0] }
        let forthcoming = volume.isForthcoming(asOf: currentYear)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(volume.title)
                    .font(.body.weight(owned != nil ? .medium : .regular))
                    .foregroundStyle(owned != nil ? .primary : .secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(volume.number.map { "\(volume.kind.label) \($0)" } ?? volume.kind.label)
                    if forthcoming, let year = volume.publishedIn {
                        Text("· à paraître en \(String(year))")
                    } else if let year = volume.publishedIn {
                        Text("· \(String(year))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let owned {
                    // The reader's own reading of this volume, in a caption
                    // label sized like the line above it: the list's default
                    // gave the glyph a column of its own and a size too big.
                    Label(owned.status.label, systemImage: owned.status.symbol)
                        .labelStyle(.caption)
                        .font(.caption)
                        .foregroundStyle(owned.status == .read ? Color.green : .secondary)
                }
            }
            Spacer(minLength: 8)

            if let owned {
                // Owned: its place in the library, then the reader's heart or
                // stars beneath, in the same right column as everywhere.
                VStack(alignment: .trailing, spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel(Text("Dans votre bibliothèque"))
                    OpinionMark(rating: owned.rating, isFavorite: owned.favorite, font: .caption)
                }
            } else if forthcoming {
                // Nothing to add: the volume does not exist yet. Batch 4 will
                // attach an alert here rather than an action.
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Pas encore paru"))
            } else if addingTitle == volume.title {
                ProgressView()
            } else {
                Button { Task { await add(volume, author: author) } } label: {
                    Image(systemName: "plus.circle").font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel(Text("Ajouter « \(volume.title) » à ma liste à lire"))
            }
        }
        .padding(.vertical, 2)
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
