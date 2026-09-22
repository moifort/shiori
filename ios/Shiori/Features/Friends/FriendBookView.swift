import SwiftUI

/// A friend's book, read-only: what it is and what the friend made of it —
/// their heart, where it sits on their shelf — never their note. What the page
/// offers is the reader's own shelf: to put the book on their pile, or among
/// the books they read, with the friend recorded as who recommended it.
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

            if let synopsis = entry.book.synopsis, !synopsis.isEmpty {
                ReadOnlySynopsisSection(synopsis: synopsis)
            }

            Section {
                actions(entry)
            } footer: {
                if !entry.inLibrary && added == nil {
                    Text("Le livre sera noté « Conseillé par \(friendName) ». Sa note de lecture reste privée.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .labelStyle(.row)
    }

    @ViewBuilder
    private func actions(_ entry: FriendBook) -> some View {
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
            AsyncButton("Ajouter à ma pile à lire", systemImage: "bookmark.fill") {
                await add(.toRead)
            }
            .accessibilityIdentifier("friend-book-add-pile")
            AsyncButton("Je l'ai déjà lu", systemImage: "checkmark") {
                await add(.read)
            }
            .accessibilityIdentifier("friend-book-add-read")
        }
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
