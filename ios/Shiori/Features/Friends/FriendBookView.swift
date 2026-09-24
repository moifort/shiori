import SwiftUI

/// A friend's book, read-only: what it is and what the friend made of it —
/// their heart, where it sits on their shelf — never their note. What the page
/// offers is the reader's own shelf, from the "+" in the corner: to put the
/// book on their pile, or among the books they read, with the friend recorded
/// as who recommended it. The "+" is greyed out on a book the reader owns. The
/// saga it belongs to opens on its own page.
struct FriendBookView: View {
    let friendId: String
    let bookId: String
    let friendName: String
    /// Called once the book is on the reader's shelf, so the screen that
    /// opened this one can say "Chez vous" without asking again.
    var onAdded: () -> Void = {}

    @State private var entry: FriendBook?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addFailed: String?
    @State private var added: CopiedStatus?

    var body: some View {
        Group {
            if isLoading && entry == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let entry {
                page(entry)
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
        .toolbar {
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

    private func page(_ entry: FriendBook) -> some View {
        List {
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

            if let synopsis = entry.book.synopsis, !synopsis.isEmpty {
                ReadOnlySynopsisSection(synopsis: synopsis)
            }

            Section {
                status(entry)
            } footer: {
                if !entry.inLibrary && added == nil {
                    Text("Le livre sera noté « Conseillé par \(friendName) ». Sa note de lecture reste privée.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
    }

    /// Where the book stands on the reader's own shelf: just added, already
    /// there, or what the "+" in the corner will do.
    @ViewBuilder
    private func status(_ entry: FriendBook) -> some View {
        if let added {
            Label(
                added == .toRead ? "Ajouté à votre pile à lire" : "Ajouté à vos livres lus",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
            .accessibilityIdentifier("friend-book-added")
        } else if entry.inLibrary {
            Label("Déjà dans votre bibliothèque", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("friend-book-owned")
        } else {
            Label("Pas encore dans votre bibliothèque", systemImage: "plus.circle")
                .foregroundStyle(.secondary)
        }
    }

    /// "+" in the corner: onto the pile, or among the books read. Greyed out
    /// once the book is the reader's.
    private func addMenu(_ entry: FriendBook) -> some View {
        let owned = entry.inLibrary || added != nil
        return Menu {
            Button("Ajouter à ma pile à lire", systemImage: "bookmark.fill") {
                Task { await add(.toRead) }
            }
            .accessibilityIdentifier("friend-book-add-pile")
            Button("Je l'ai déjà lu", systemImage: "checkmark") {
                Task { await add(.read) }
            }
            .accessibilityIdentifier("friend-book-add-read")
        } label: {
            Label("Ajouter à ma bibliothèque", systemImage: "plus")
        }
        .disabled(owned)
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

    private func add(_ status: CopiedStatus) async {
        do {
            try await FriendsAPI.addBook(friendId: friendId, bookId: bookId, status: status)
            added = status
            onAdded()
        } catch {
            addFailed = reportError(error)
        }
    }
}
