import SwiftUI

/// A volume announced, opened as a book opens — from the Books shelf of
/// Découvrir, or from its row on the saga screen — drawn as an awaited edition
/// is: when it comes on top — orange while announced, green once out — then the
/// book's own section, with Audible's tag in its corner for a recording, and
/// the way to its saga where the book page has it. Only what the weekly look
/// found is drawn: the page asks nothing of the model and opens at once.
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

    var body: some View {
        List {
            Section {} header: { stateLine }

            ReadOnlyBookHeader(
                book: book,
                storeLink: volume.audibleURL.map { .init(name: "Audible", url: $0) },
                onOpenSeries: linksToSaga ? { showsSaga = true } : nil
            )

            if added {
                Section {
                    Label("Ajouté à votre pile à lire", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("announced-volume-added")
                }
            }
        }
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

    /// When it comes out, or that it is out, on a bookmark ribbon: a volume
    /// just out is opened from "Nouvelles parutions".
    private var stateLine: some View {
        Group {
            if let date = volume.date, ReleaseDateText.isUpcoming(date) {
                ReleaseRibbon(text: ReleaseDateText.coming(date), systemImage: "clock", tint: .orange)
            } else if let date = volume.date {
                ReleaseRibbon(text: ReleaseDateText.out(date), systemImage: "checkmark.circle", tint: .green)
            } else {
                ReleaseRibbon(text: String(localized: "Annoncé"), systemImage: "clock", tint: .gray)
            }
        }
        .ribbonRow()
        .accessibilityIdentifier("announced-volume-release")
    }

    /// What the weekly look knows: its title, author, cover and place in the
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
        let shown = book
        var draft = BookDraft(title: shown.title, authors: shown.authors)
        draft.format = shown.format
        // The saga's genre: the page does not draw it, but the book is filed
        // under it as its saga is.
        draft.genre = series.genre
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
