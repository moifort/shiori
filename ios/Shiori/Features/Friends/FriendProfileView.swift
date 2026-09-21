import SwiftUI

/// One friend's shelf: what they are reading, their pile, what they keep close
/// and the sagas they are working through.
///
/// Read-only, and it stays that way. Every row here is somebody else's book:
/// tapping one would open a screen full of controls that write to a library
/// that is not the reader's. What this screen is for is knowing what a friend
/// is reading, which is what it shows.
///
/// Books they marked "do not share" are absent, and no reading note is drawn:
/// a friend sees a shelf, not a diary.
struct FriendProfileView: View {
    let friend: Friend

    @State private var profile: FriendProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && profile == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile, !profile.isEmpty {
                shelves(profile)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Bibliothèque indisponible", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    AsyncButton("Réessayer") { await load() }
                }
            } else {
                ContentUnavailableView {
                    Label("Rien à voir pour l'instant", systemImage: "books.vertical")
                } description: {
                    Text("\(friend.displayName) n'a encore rien à partager.")
                }
            }
        }
        .navigationTitle(profile?.displayName ?? friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func shelves(_ profile: FriendProfile) -> some View {
        List {
            shelf("En cours", books: profile.reading, empty: "Aucune lecture en cours.")
            shelf("Ses favoris", books: profile.favorites, empty: "Aucun favori.")
            if !profile.sagas.isEmpty {
                Section("Ses séries") {
                    ForEach(profile.sagas) { saga in
                        sagaRow(saga)
                    }
                }
            }
            shelf("Sa pile à lire", books: profile.pile, empty: "Sa pile est vide.")
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
    }

    @ViewBuilder
    private func shelf(_ title: LocalizedStringKey, books: [Book], empty: LocalizedStringKey)
        -> some View
    {
        Section(title) {
            if books.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(books) { book in
                    BookRow(
                        title: book.title,
                        authorLine: book.authorLine,
                        cover: book,
                        status: book.status,
                        rating: book.rating,
                        volumeLabel: book.series?.label,
                        genre: book.genre,
                        subgenre: book.subgenres.first,
                        format: book.format,
                        language: book.language,
                        isFavorite: book.favorite
                    )
                }
            }
        }
    }

    /// How many volumes of a saga are on their shelf, never how many the saga
    /// has: the catalogue is not something a friendship opens.
    private func sagaRow(_ saga: FriendSaga) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(saga.name).font(.body.weight(.medium))
                    if let language = saga.language, language.isForeign {
                        LanguageTag(language: language)
                    }
                }
                if let author = saga.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Label("\(saga.ownedCount) tome(s)", systemImage: "books.vertical")
                .labelStyle(.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            profile = try await FriendsAPI.profile(userId: friend.userId)
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }
}
