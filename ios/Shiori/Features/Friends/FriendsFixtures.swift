import Foundation

// The friends' screens' preview and test data: a friend's shelf, two friends
// as the Partagé list draws them, a book on a friend's shelf, an invitation.

extension FriendProfile {
    static let preview: FriendProfile = {
        let hunter = FriendBook(
            book: Book(
                id: "hunter", title: "Primal Hunter", authors: ["Zogarth"], format: .audiobook,
                listeningProgress: 32,
                series: SeriesMembership(id: "ph", name: "Primal Hunter", volume: 6, kind: .main),
                status: .reading
            ),
            inLibrary: true,
            lastActivityAt: .now.addingTimeInterval(-3600)
        )
        let wind = FriendBook(
            book: Book(
                id: "wind", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .read,
                favorite: true, finishedAt: .now.addingTimeInterval(-86400 * 4)
            ),
            inLibrary: false,
            favoritedAt: .now.addingTimeInterval(-86400 * 20)
        )
        let dune = FriendBook(
            book: Book(id: "dune", title: "Dune", authors: ["Frank Herbert"], status: .read, favorite: true),
            inLibrary: false,
            favoritedAt: .now.addingTimeInterval(-86400 * 9)
        )
        let ulysse = FriendBook(
            book: Book(id: "ulysse", title: "Ulysse", authors: ["James Joyce"], status: .dropped),
            inLibrary: false,
            lastActivityAt: .now.addingTimeInterval(-86400 * 2)
        )
        var silo = FriendBook(
            book: Book(id: "silo", title: "Silo", authors: ["Hugh Howey"], status: .toRead),
            inLibrary: false
        )
        silo.book.addedAt = .now.addingTimeInterval(-86400)
        let reading = [
            ("piranesi", "Piranesi", "Susanna Clarke"),
            ("lune", "La Lune est une maîtresse cruelle", "Robert A. Heinlein"),
            ("hypérion", "Hypérion", "Dan Simmons"),
        ].map { id, title, author in
            FriendBook(book: Book(id: id, title: title, authors: [author], status: .reading), inLibrary: false)
        }
        let favorites = [
            ("fondation", "Fondation", "Isaac Asimov"),
            ("ubik", "Ubik", "Philip K. Dick"),
        ].map { id, title, author in
            FriendBook(
                book: Book(id: id, title: title, authors: [author], status: .read, favorite: true),
                inLibrary: false
            )
        }
        return FriendProfile(
            userId: "camille",
            firstName: "Camille",
            reading: [hunter] + reading,
            pile: [silo] + reading.prefix(2),
            favorites: [dune, wind] + favorites,
            sagas: [],
            lastFinished: wind,
            lastDropped: ulysse,
            lastAdded: silo,
            bookCount: 9,
            readThisYear: 2
        )
    }()
}

extension Friend {
    /// Two friends as the list draws them: one whose whole shelf moved lately,
    /// one who only picked a book up.
    static let previews: [Friend] = [
        Friend(seenByFriends: .preview),
        Friend(
            userId: "leo",
            firstName: "Léo",
            since: .now,
            bookCount: 12,
            favoriteCount: 2,
            readingCount: 1,
            toReadCount: 4,
            readThisYear: 3,
            recentActivity: FriendProfile.preview.reading.dropFirst().prefix(1).map {
                .reading($0, at: .now.addingTimeInterval(-7200))
            }
        ),
    ]
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

extension FriendInvitation {
    static let preview = FriendInvitation(code: "K7Q2MX9P", expiresAt: .now.addingTimeInterval(86400 * 7))
}
