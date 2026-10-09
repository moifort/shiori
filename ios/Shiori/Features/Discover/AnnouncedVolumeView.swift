import SwiftUI

/// A volume announced, opened as a book opens — from the Books shelf of
/// Découvrir, or from its row on the saga screen — drawn as every book page
/// is, when it comes pinned on its cover — orange while announced, green once
/// out — with Audible's tag in its corner for a recording, and the way to its
/// saga where the book page has it. It opens at once on what the look on the
/// web found, then fills in as a book's page — summary, genre, pages,
/// publisher, narrators — once the model described it, for every reader at
/// once, so it spends no scan.
///
/// "+" puts it on the pile, filed in its saga at its number; a recording goes
/// through the reader's Audible account when there is one, as the saga screen
/// adds it.
struct AnnouncedVolumeView: View {
    let saga: SagaDiscovery
    let volume: DiscoveredVolume
    /// Whether the page links to its saga. Not when it was opened from the saga
    /// screen, which is right under it.
    var linksToSaga = true

    @Environment(\.dismiss) private var dismiss

    @State private var showsSaga = false
    @State private var isAdding = false
    @State private var added = false
    @State private var addFailed: String?
    @State private var describer = ReleaseDescriber()

    var body: some View {
        List {
            BookHeaderSection(
                book: shown,
                state: state,
                releaseDate: volume.date,
                storeLink: volume.audibleURL.map { .init(name: "Audible", url: $0, tint: .audible) },
                actions: .init(openSeries: linksToSaga ? { showsSaga = true } : nil)
            )
            ReleaseDescriptionSections(describer: describer, synopsis: shown.synopsis)
        }
        .task { await describer.describe(seed) }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
        .navigationTitle(Text(verbatim: saga.series.name))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsSaga) {
            SeriesView(seriesId: saga.series.seriesId, language: saga.series.language)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                if isAdding {
                    ProgressView()
                } else {
                    Button("Ajouter à ma pile", systemImage: "plus") {
                        Task { await add() }
                    }
                    .disabled(added)
                    .accessibilityIdentifier("announced-volume-add")
                }
            }
        }
        .alert(
            "Ajout impossible",
            isPresented: .init(get: { addFailed != nil }, set: { if !$0 { addFailed = nil } })
        ) {
            Button("OK", role: .cancel) { addFailed = nil }
        } message: {
            Text(addFailed ?? "")
        }
    }

    /// Said under the author only when the calendar leaf in the corner does
    /// not say it already: once added, once out, or with no date yet.
    private var state: BookState? {
        if added { return .addedToPile }
        if let date = volume.date, ReleaseDateText.isUpcoming(date) { return nil }
        return .release(volume.date)
    }

    /// The book once described, or as the look on the web knows it until then.
    private var shown: Book { book.described(by: describer.description) }

    /// What the model is told: the volume as the watch found it.
    private var seed: ReleaseSeed {
        ReleaseSeed(
            title: book.title,
            authors: book.authors,
            format: book.format,
            language: book.language,
            series: book.series,
            isbn13: volume.isbn13,
            releasedOn: volume.date,
            coverURL: volume.coverURL
        )
    }

    /// What the look on the web knows: its title, author, cover and place in the
    /// saga.
    private var book: Book {
        let series = saga.series
        return Book(
            id: "release-\(series.id)-\(volume.number)",
            title: volume.title,
            authors: series.author.map { [$0] } ?? [],
            format: series.isAudio ? .audiobook : .book,
            isbn13: volume.isbn13,
            language: series.language,
            series: SeriesMembership(
                id: series.seriesId,
                name: series.name,
                volume: volume.number,
                kind: .main
            ),
            coverURL: volume.coverURL,
            status: .toRead
        )
    }

    private func add() async {
        isAdding = true
        defer { isAdding = false }
        let series = saga.series
        // A recording is best added through the reader's Audible account: it
        // keeps its link to the title, as an import does. Without one, it is
        // added from its page, as a printed volume is.
        if series.isAudio, let language = series.language {
            do {
                _ = try await SeriesAPI.addAudibleVolume(
                    seriesId: series.seriesId,
                    volume: volume.number,
                    language: language
                )
                track(.bookAdded(source: .discover))
                added = true
                return
            } catch {
                let code = (error as? APIError)?.domainCode
                if code != "NOT_FOUND" && code != "AUDIBLE_NOT_CONNECTED" { _ = reportError(error) }
            }
        }
        let shown = shown
        var draft = BookDraft(title: shown.title, authors: shown.authors)
        draft.format = shown.format
        // The description's genre, else the saga's: the book is filed under
        // it as its saga is.
        draft.genre = shown.genre ?? series.genre
        draft.subgenres = shown.subgenres
        draft.synopsis = shown.synopsis
        draft.publisher = shown.publisher
        draft.firstPublishedIn = shown.firstPublishedIn
        draft.pageCount = shown.pageCount
        draft.isbn13 = shown.isbn13
        draft.language = series.language
        draft.series = shown.series
        draft.coverURL = shown.coverURL
        draft.status = .toRead
        do {
            _ = try await BookAPI.add(draft)
            track(.bookAdded(source: .discover))
            added = true
        } catch {
            addFailed = reportError(error)
        }
    }
}

extension SagaDiscovery {
    static let preview = SagaDiscovery(
        series: FollowedSeries(
            seriesId: "dcc",
            name: "Dungeon Crawler Carl",
            isAudio: true,
            author: "Matt Dinniman",
            language: .fr,
            state: .inProgress,
            genre: .fantasy,
            ownedCount: 7
        ),
        releases: SagaReleases(
            watched: true,
            next: DiscoveredVolume(
                number: 8,
                title: "Le Livre du Carnage",
                date: "2026-11-05",
                isbn13: nil,
                coverURL: nil
            )
        )
    )
}

#Preview("Announced volume") {
    NavigationStack {
        AnnouncedVolumeView(saga: .preview, volume: SagaDiscovery.preview.releases.next!)
    }
}
