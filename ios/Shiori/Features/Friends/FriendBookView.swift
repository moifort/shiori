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

/// What a friend's book page draws once the book is known: the warning of a
/// book the reader holds already, the book, what the friend made of it, its
/// saga, the editions awaited, and where it stands on the reader's own shelf.
struct FriendBookPage: View {
    let entry: FriendBook
    let friendName: String
    /// What the reader just did with it from the "+" in the corner.
    let added: CopiedStatus?
    let awaited: [AwaitedEdition]
    let onStopAwaiting: (AwaitedEdition) -> Void

    var body: some View {
        List {
            // A warning before anything else: the page is about a book the
            // reader already holds, and its "+" is greyed out for that.
            if entry.inLibrary && added == nil {
                Section {} header: {
                    ReleaseRibbon(
                        text: String(localized: "Déjà dans votre bibliothèque"),
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .orange
                    )
                    .ribbonRow()
                    .accessibilityIdentifier("friend-book-owned")
                }
            }

            ReadOnlyBookHeader(book: entry.book)

            Section {
                if entry.book.favorite {
                    Label {
                        Text("Coup de cœur de \(friendName)")
                    } icon: {
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                    }
                } else if let rating = entry.book.rating {
                    Label {
                        LabeledContent("Note de \(friendName)") { StarRatingView(rating: rating) }
                    } icon: {
                        Image(systemName: "star").foregroundStyle(.secondary)
                    }
                }
                Label {
                    LabeledContent("Chez \(friendName)") { Text(entry.book.status.label) }
                } icon: {
                    Image(systemName: entry.book.status.symbol).foregroundStyle(entry.book.status.tint)
                }
            }

            if let series = entry.book.series {
                Section {
                    NavigationLink {
                        SeriesView(seriesId: series.id, language: entry.book.language)
                    } label: {
                        Label {
                            LabeledContent(series.name) { Text(series.label) }
                        } icon: {
                            Image(systemName: "books.vertical").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("friend-book-series")
                }
            }

            AwaitedEditionsSection(awaited: awaited, onStop: onStopAwaiting)

            if let synopsis = entry.book.synopsis, !synopsis.isEmpty {
                ReadOnlySynopsisSection(synopsis: synopsis)
            }

            if !entry.inLibrary || added != nil {
                Section {
                    status
                } footer: {
                    if added == nil {
                        Text("Le livre sera noté « Conseillé par \(friendName) ». Sa note de lecture reste privée.")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
    }

    /// Where the book stands on the reader's own shelf: just added, or what
    /// the "+" in the corner will do. A book already there says so at the top.
    @ViewBuilder
    private var status: some View {
        if let added {
            Label(
                added == .toRead ? "Ajouté à votre pile à lire" : "Ajouté à vos livres lus",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
            .accessibilityIdentifier("friend-book-added")
        } else {
            Label("Pas encore dans votre bibliothèque", systemImage: "plus.circle")
                .foregroundStyle(.secondary)
        }
    }
}
