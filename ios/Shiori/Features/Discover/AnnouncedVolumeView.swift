import SwiftUI

/// A volume announced, opened as a book opens — from the Books shelf of
/// Découvrir, or from its row on the saga screen:
/// its page, before the reader holds it. The page is described on the spot — a
/// printed volume by the model, a recording off Audible's catalogue and then
/// by the model — which takes a few seconds and spends one scan. What the row
/// already knows is drawn at once, and the rest fills in.
///
/// The description is kept for the session, so opening the volume again spends
/// nothing. "+" puts it on the pile, filed in its saga at its number; a
/// recording goes through the reader's Audible account when there is one, as
/// the saga screen adds it.
struct AnnouncedVolumeView: View {
    let saga: SagaDiscovery
    let volume: DiscoveredVolume
    /// Whether the page links to its saga. Not when it was opened from the saga
    /// screen, which is right under it.
    var linksToSaga = true

    @Environment(\.dismiss) private var dismiss

    @State private var preview: AnnouncedVolumePreview?
    @State private var isDescribing = false
    @State private var failure: String?
    @State private var allowanceSpent = false
    @State private var showsPremium = false
    @State private var isAdding = false
    @State private var added = false
    @State private var addFailed: String?

    var body: some View {
        List {
            if let date = preview?.releaseDate ?? volume.date, ReleaseDateText.isUpcoming(date) {
                Section {
                    Label(ReleaseDateText.coming(date), systemImage: "clock")
                        .foregroundStyle(.orange)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("announced-volume-release")
                }
            }

            ReadOnlyBookHeader(book: book)

            if isDescribing || failure != nil || allowanceSpent {
                Section { describing }
            }

            if let audibleURL = preview?.audibleURL ?? volume.audibleURL {
                Section {
                    Link(destination: audibleURL) {
                        Label("Ouvrir dans Audible", systemImage: "headphones")
                    }
                    .accessibilityIdentifier("announced-volume-audible")
                }
            }

            if linksToSaga {
                sagaLink
            }

            if let synopsis = book.synopsis, !synopsis.isEmpty {
                ReadOnlySynopsisSection(synopsis: synopsis)
            }

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
                    .disabled(added || isDescribing)
                    .accessibilityIdentifier("announced-volume-add")
                }
            }
        }
        .sheet(isPresented: $showsPremium) {
            PremiumSheet(trigger: .scanAllowanceSpent)
        }
        .alert(
            "Ajout impossible",
            isPresented: .init(get: { addFailed != nil }, set: { if !$0 { addFailed = nil } })
        ) {
            Button("OK", role: .cancel) { addFailed = nil }
        } message: {
            Text(addFailed ?? "")
        }
        .task { await describe() }
    }

    /// The saga the volume belongs to, at its number.
    private var sagaLink: some View {
        Section {
            NavigationLink {
                SeriesView(seriesId: saga.series.seriesId, language: saga.series.language)
            } label: {
                Label {
                    LabeledContent(saga.series.name) { Text("Tome \(volume.number)") }
                } icon: {
                    Image(systemName: "books.vertical").foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("announced-volume-series")
        }
    }

    /// Where the description stands, while it is written or when it could not
    /// be: the page still shows what the row knew, and the volume can be added
    /// all the same.
    @ViewBuilder
    private var describing: some View {
        if isDescribing {
            HStack(spacing: 10) {
                ProgressView()
                Text("Préparation de la fiche…").foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("announced-volume-describing")
        } else if allowanceSpent {
            Button("Plus de scan ce mois-ci : voir Premium", systemImage: "sparkles") {
                showsPremium = true
            }
            .accessibilityIdentifier("announced-volume-premium")
        } else if failure != nil {
            Button("Fiche indisponible. Réessayer", systemImage: "arrow.clockwise") {
                Task { await describe() }
            }
            .accessibilityIdentifier("announced-volume-retry")
        }
    }

    /// The page drawn: what the model and Audible described, else what the row
    /// knows — its title, author, cover and place in the saga.
    private var book: Book {
        let series = saga.series
        let membership = SeriesMembership(
            id: series.seriesId,
            name: series.name,
            volume: volume.number,
            kind: .main
        )
        let described = preview?.book
        return Book(
            id: "release-\(series.id)-\(volume.number)",
            title: described?.title ?? volume.title,
            authors: described.map(\.authors).flatMap { $0.isEmpty ? nil : $0 }
                ?? series.author.map { [$0] } ?? [],
            format: series.isAudio ? .audiobook : .book,
            publisher: described?.publisher,
            firstPublishedIn: described?.firstPublishedIn,
            synopsis: described?.synopsis,
            genre: described?.genre ?? series.genre,
            subgenres: described?.subgenres ?? [],
            pageCount: described?.pageCount,
            durationMinutes: preview?.durationMinutes,
            narrators: preview?.narrators ?? [],
            isbn13: described?.isbn13 ?? volume.isbn13,
            language: series.language,
            series: membership,
            coverURL: described?.coverURL ?? volume.coverURL,
            status: .toRead
        )
    }

    private var cacheKey: String { "\(saga.series.id)--\(volume.number)" }

    private func describe() async {
        if let kept = AnnouncedVolumeCache.entries[cacheKey] {
            preview = kept
            return
        }
        guard let language = saga.series.language else { return }
        isDescribing = true
        failure = nil
        defer { isDescribing = false }
        do {
            let described = try await DiscoverAPI.preview(
                seriesId: saga.series.seriesId,
                language: language,
                number: volume.number
            )
            AnnouncedVolumeCache.entries[cacheKey] = described
            preview = described
        } catch let APIError.domain(code, _) where code == "QUOTA_EXHAUSTED" {
            allowanceSpent = true
        } catch {
            failure = reportError(error)
        }
    }

    private func add() async {
        isAdding = true
        defer { isAdding = false }
        let series = saga.series
        // A recording is best added through the reader's Audible account: it
        // keeps its link to the title, as an import does. Without one, it is
        // added from its page below, as a printed volume is.
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
        var draft = preview?.book.asDraft ?? BookDraft(title: shown.title, authors: shown.authors)
        draft.title = shown.title
        draft.authors = shown.authors
        draft.format = shown.format
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

/// What each announced volume was described as, for the session: opening it
/// again spends no second scan.
@MainActor
enum AnnouncedVolumeCache {
    static var entries: [String: AnnouncedVolumePreview] = [:]
}
