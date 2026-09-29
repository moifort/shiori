import SwiftUI

/// A friend's book, read-only: what it is and what the friend made of it —
/// their heart, where it sits on their shelf — never their note. What the page
/// offers is the reader's own shelf, from the "+" in the corner: to put the
/// book on their pile, or among the books they read, with the friend recorded
/// as who recommended it. The "+" is greyed out on a book the reader owns. The
/// saga it belongs to opens on its own page, pushed inside the sheet.
///
/// Always opened as a sheet, as a book opens from the reader's own library:
/// a close button in the corner.
struct FriendBookView: View {
    let friendId: String
    let bookId: String
    let friendName: String
    /// Called once the book is on the reader's shelf, so the screen that
    /// opened this one can say "Chez vous" without asking again.
    var onAdded: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var entry: FriendBook?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addFailed: String?
    @State private var added: CopiedStatus?
    /// Whether Audible sells the book, for a printed one: until it answers,
    /// and when it cannot, the reader may still take it heard.
    @State private var audio: AudioAvailability?
    /// What the page offers to await in the app's language — the translation,
    /// the recording, or the recording Audible does not sell yet — and what
    /// the reader awaits already.
    @State private var offer = EditionOffer()
    /// The awaits sent and not answered yet, by format: the page already shows
    /// them, so giving one up waits for the server's id.
    @State private var awaiting: [ReleaseFormat: Task<AwaitedEdition?, Never>] = [:]

    var body: some View {
        Group {
            if isLoading && entry == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let entry {
                FriendBookPage(
                    entry: entry,
                    friendName: friendName,
                    added: added,
                    awaited: offer.awaited
                ) { edition in
                    Task { await stopAwaiting(edition) }
                }
            } else if let errorMessage {
                EmptyStateView.failure("Livre indisponible", message: errorMessage) { await load() }
            } else {
                EmptyStateView(
                    systemImage: "book.closed",
                    title: "Livre introuvable",
                    message: "Ce livre n'est plus partagé."
                )
            }
        }
        .navigationTitle(Text(verbatim: String(localized: "Chez \(friendName)")))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task { await loadAudio() }
        .task { await loadOffer() }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
            }
            if let entry {
                ToolbarItem(placement: .primaryAction) { addMenu(entry) }
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

    /// "+" in the corner: onto the pile, or among the books read, in print or
    /// as a recording — a reader who never listens takes a friend's recording
    /// as a book, and a printed book is offered heard once Audible confirms
    /// it sells it. Its French edition, translated or recorded, may be awaited
    /// from here too — the recording in place of taking it heard, when Audible
    /// does not sell it yet. Greyed out once nothing is left to do.
    private func addMenu(_ entry: FriendBook) -> some View {
        let owned = entry.inLibrary || added != nil
        let formats = entry.book.format.takenAs.filter { $0 != .audiobook || audio != .unavailable }
        return Menu {
            if !owned {
                ForEach(formats, id: \.self) { format in
                    Section(format.label) {
                        Button("Ajouter à ma pile", systemImage: "bookmark.fill") {
                            Task { await add(.toRead, as: format) }
                        }
                        .accessibilityIdentifier("friend-book-add-pile-\(format.rawValue)")
                        Button(
                            format == .audiobook ? "Je l'ai déjà écouté" : "Je l'ai déjà lu",
                            systemImage: "checkmark"
                        ) {
                            Task { await add(.read, as: format) }
                        }
                        .accessibilityIdentifier("friend-book-add-read-\(format.rawValue)")
                    }
                }
            }
            if !offer.awaitable.isEmpty {
                Section {
                    ForEach(offer.awaitable) { format in
                        Button(
                            format.awaitLabel,
                            systemImage: format == .audiobook ? "headphones" : "character.book.closed"
                        ) {
                            awaitEdition(format, of: entry.book)
                        }
                        .accessibilityIdentifier("friend-book-await-\(format.rawValue)")
                    }
                }
            }
        } label: {
            Label("Ajouter à ma bibliothèque", systemImage: "plus")
        }
        .disabled(owned && offer.awaitable.isEmpty)
        .accessibilityIdentifier("friend-book-add-menu")
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            entry = try await FriendsAPI.book(friendId: friendId, bookId: bookId)
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    private func loadOffer() async {
        do {
            offer = try await AwaitedAPI.offer(friendId: friendId, bookId: bookId) ?? EditionOffer()
        } catch {
            _ = reportError(error)
        }
    }

    /// Awaits the book's edition in the app's language. The page shows it
    /// awaited at once, with no loader: the server looks it up on the web
    /// behind, and its answer replaces the line when it comes.
    private func awaitEdition(_ format: ReleaseFormat, of book: Book) {
        let pending = AwaitedEdition.pending(format: format, of: book)
        offer.awaited.append(pending)
        awaiting[format] = Task {
            defer { awaiting[format] = nil }
            do {
                let edition = try await AwaitedAPI.awaitEdition(
                    friendId: friendId,
                    bookId: bookId,
                    format: format
                )
                // Unless the reader gave it up meanwhile.
                if let index = offer.awaited.firstIndex(where: { $0.id == pending.id }) {
                    offer.awaited[index] = edition
                }
                return edition
            } catch {
                offer.awaited.removeAll { $0.id == pending.id }
                addFailed = reportError(error)
                return nil
            }
        }
    }

    private func stopAwaiting(_ edition: AwaitedEdition) async {
        var edition = edition
        // Given up before the server answered: stopped once it has.
        if let pending = awaiting[edition.format] {
            offer.awaited.removeAll { $0.id == edition.id }
            guard let answered = await pending.value else { return }
            edition = answered
        }
        do {
            try await AwaitedAPI.stop(id: edition.id)
            offer.awaited.removeAll { $0.id == edition.id }
        } catch {
            addFailed = reportError(error)
        }
    }

    private func loadAudio() async {
        do {
            audio = try await FriendsAPI.audio(friendId: friendId, bookId: bookId)
        } catch {
            _ = reportError(error)
        }
    }

    private func add(_ status: CopiedStatus, as format: BookFormat) async {
        do {
            try await FriendsAPI.addBook(
                friendId: friendId,
                bookId: bookId,
                status: status,
                format: format
            )
            added = status
            onAdded()
        } catch {
            addFailed = reportError(error)
        }
    }
}

/// What a friend's book page draws once the book is known: the reader's own
/// book page, read-only — the friend's status, the book with where it stands
/// for the reader pinned on its cover, the editions awaited, the friend's
/// reading, and the summary.
struct FriendBookPage: View {
    let entry: FriendBook
    let friendName: String
    /// What the reader just did with it from the "+" in the corner.
    let added: CopiedStatus?
    let awaited: [AwaitedEdition]
    let onStopAwaiting: (AwaitedEdition) -> Void

    @State private var showsSaga = false

    /// Where the book stands for the reader, pinned on its cover: just added
    /// from the "+" in the corner, or held already, which is why the "+" is
    /// greyed out.
    private var state: BookState? {
        switch added {
        case .toRead: .addedToPile
        case .read: .addedAsRead
        case nil: entry.inLibrary ? .owned : nil
        }
    }

    var body: some View {
        List {
            // Laid out as the reader's own page, row for row, so a book reads
            // the same on either shelf: where it stands, what it is, how it
            // was read, what it is about. Only what cannot be done here goes.
            BookStatusSection(status: entry.book.status)
            BookHeaderSection(
                book: entry.book,
                state: state,
                actions: .init(openSeries: { showsSaga = true })
            )
            AwaitedEditionsSection(awaited: awaited, onStop: onStopAwaiting)
            BookReadingSection(
                title: "Lecture de \(friendName)",
                book: entry.book,
                footer: state == nil
                    ? "Le livre sera noté « Conseillé par \(friendName) ». Sa note de lecture reste privée."
                    : nil
            ) {
                if entry.book.favorite {
                    Label {
                        Text("Coup de cœur")
                    } icon: {
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                    }
                    .accessibilityIdentifier("friend-book-favorite")
                }
            }
            if let synopsis = entry.book.synopsis, !synopsis.isEmpty {
                BookSynopsisSection(synopsis: synopsis)
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
        .navigationDestination(isPresented: $showsSaga) {
            if let series = entry.book.series {
                SeriesView(seriesId: series.id, language: entry.book.language)
            }
        }
    }
}

extension FriendBook {
    static let preview = FriendBook(
        book: Book(
            id: "preview",
            title: "Le Nom du vent",
            authors: ["Patrick Rothfuss"],
            publisher: "Bragelonne",
            firstPublishedIn: 2007,
            synopsis: "Kvothe raconte sa vie, de la troupe de comédiens où il a grandi à l'Université.",
            genre: .fantasy,
            subgenres: ["Roman initiatique"],
            pageCount: 662,
            isbn13: "9782352943556",
            series: SeriesMembership(id: "kkc", name: "Chronique du tueur de roi", volume: 1, kind: .main),
            status: .read,
            rating: 5,
            favorite: true,
            addedAt: .now.addingTimeInterval(-86400 * 60),
            startedAt: .now.addingTimeInterval(-86400 * 40),
            finishedAt: .now.addingTimeInterval(-86400 * 10)
        ),
        inLibrary: true
    )
}

#Preview("Friend's book held already") {
    NavigationStack {
        FriendBookPage(entry: .preview, friendName: "Camille", added: nil, awaited: []) { _ in }
            .navigationTitle("Chez Camille")
            .navigationBarTitleDisplayMode(.inline)
    }
}
